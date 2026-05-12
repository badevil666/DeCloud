import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:hex/hex.dart';
import 'package:http/http.dart' as http;
import 'package:media_scanner/media_scanner.dart';

import '../auth/auth_service.dart';
import '../config/api_config_service.dart';
import '../config/relay_config_service.dart';
import 'download_models.dart';

class DownloadService {
  static const int _maxChunkRetries = 3;
  static const _connectTimeout = Duration(seconds: 10);
  static const _pairTimeout = Duration(seconds: 60);
  static const _chunkTimeout = Duration(seconds: 120);

  /// Downloads a file by [fileId] and writes the assembled result to [outputPath].
  ///
  /// [onProgress] is called with a short human-readable status string at each
  /// key step (manifest fetch, relay connect, chunk download, verify, save).
  ///
  /// Flow:
  ///   1. POST /client/files/:fileId/download → [DownloadManifest]
  ///   2. For each chunk (in order): connect to relay, receive binary, verify hash.
  ///      On failure: re-POST to get a fresh peer assignment and retry.
  ///   3. Verify merkleRoot = SHA-256(chunk_hash_0_bytes || ... || chunk_hash_N_bytes).
  ///   4. Write reassembled file to [outputPath].
  ///
  /// Returns [outputPath] on success.
  static Future<String> download({
    required String fileId,
    required String outputPath,
    void Function(String status)? onProgress,
  }) async {
    final baseUrl = await ApiConfigService.getBaseUrl();
    final relayUrl = await RelayConfigService.getBaseUrl();
    final token = await AuthService.getToken();
    if (token == null) throw Exception('Not authenticated. Please log in first.');

    // Step 1: Request initial manifest
    onProgress?.call('Fetching manifest...');
    var manifest = await _requestManifest(baseUrl, token, fileId);
    final total = manifest.chunks.length;
    print('[Download] Manifest received — $total chunk(s) for "${manifest.filename}"');

    // Sort by chunkIndex to guarantee reassembly order
    final sortedChunks = List<DownloadChunkInfo>.from(manifest.chunks)
      ..sort((a, b) => a.chunkIndex.compareTo(b.chunkIndex));

    // Step 2: Download each chunk with per-chunk retry
    final assembledChunks = <Uint8List>[];

    for (final original in sortedChunks) {
      Uint8List? data;
      Exception? lastError;
      var currentChunkInfo = original;
      var currentRelayUrl = relayUrl;

      for (int attempt = 1; attempt <= _maxChunkRetries; attempt++) {
        if (attempt > 1) {
          // Re-request manifest so the coordinator picks a live replica
          print('[Download] Re-requesting manifest for chunk ${original.chunkIndex} (attempt $attempt)');
          onProgress?.call('Retrying chunk ${original.chunkIndex + 1}/$total...');
          manifest = await _requestManifest(baseUrl, token, fileId);
          currentChunkInfo = manifest.chunks.firstWhere(
            (c) => c.chunkIndex == original.chunkIndex,
            orElse: () => throw Exception(
                'Chunk ${original.chunkIndex} missing from refreshed manifest'),
          );
          currentRelayUrl = relayUrl;
        }

        try {
          data = await _downloadChunk(
            currentRelayUrl,
            currentChunkInfo,
            onProgress: (s) => onProgress?.call(s),
            chunkLabel: '${original.chunkIndex + 1}/$total',
          );
          break; // success
        } catch (e) {
          lastError = e is Exception ? e : Exception(e.toString());
          print('[Download] Chunk ${original.chunkIndex} attempt $attempt failed: $e');
        }
      }

      if (data == null) {
        throw lastError ??
            Exception('Failed to download chunk ${original.chunkIndex} after $_maxChunkRetries attempts');
      }

      assembledChunks.add(data);
    }

    // Step 3: Verify merkleRoot = SHA-256(concatenated chunk hash hex strings)
    // Matches backend: sha256(chunkInfo.map((c) => c.hash).join(''))
    onProgress?.call('Verifying integrity...');
    final sha256 = Sha256();
    final concatenated = sortedChunks.map((c) => c.chunkHash).join();
    final computedRoot = HEX.encode(
      (await sha256.hash(Uint8List.fromList(utf8.encode(concatenated)))).bytes,
    );

    if (computedRoot != manifest.merkleRoot) {
      throw Exception(
          'File integrity check failed: merkleRoot mismatch\n'
          '  computed : $computedRoot\n'
          '  expected : ${manifest.merkleRoot}');
    }
    print('[Download] merkleRoot verified');

    // Step 4: Write reassembled file
    onProgress?.call('Saving file...');
    final file = File(outputPath);
    await file.parent.create(recursive: true);
    final sink = file.openWrite();
    for (final chunk in assembledChunks) {
      sink.add(chunk);
    }
    await sink.close();

    final totalBytes = assembledChunks.fold<int>(0, (s, c) => s + c.length);
    print('[Download] Written $totalBytes bytes → $outputPath');

    // Notify Android MediaStore so the file appears in file managers/gallery
    await MediaScanner.loadMedia(path: outputPath);

    return outputPath;
  }

  // ---------------------------------------------------------------------------
  // Manifest request
  // ---------------------------------------------------------------------------

  static Future<DownloadManifest> _requestManifest(
    String baseUrl,
    String token,
    String fileId,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/client/files/$fileId/download'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    switch (response.statusCode) {
      case 200:
        return DownloadManifest.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      case 404:
        throw Exception('File not found or does not belong to this account.');
      case 409:
        throw Exception('File is not fully stored yet. Please try again later.');
      case 503:
        throw Exception(
            'One or more chunks are currently unavailable. Please try again later.');
      default:
        throw Exception(
            'Manifest request failed: ${response.statusCode} ${response.body}');
    }
  }

  // ---------------------------------------------------------------------------
  // Single-chunk relay download
  // ---------------------------------------------------------------------------

  static Future<Uint8List> _downloadChunk(
    String relayUrl,
    DownloadChunkInfo chunkInfo, {
    void Function(String)? onProgress,
    String chunkLabel = '',
  }) async {
    final wsUrl = _toWsUrl(relayUrl, chunkInfo.token, chunkInfo.chunkIndex);
    onProgress?.call('Connecting to relay · chunk $chunkLabel');
    print('[Download] Connecting to relay (chunk ${chunkInfo.chunkIndex}, token: ${chunkInfo.token.substring(0, 8)}...)');

    final ws = await WebSocket.connect(wsUrl).timeout(_connectTimeout);
    final session = _DownloadWsSession(ws);
    try {
      // Wait for paired
      while (true) {
        final msg = await session.nextJsonMessage().timeout(_pairTimeout);
        final type = msg['type'] as String?;
        if (type == 'paired') {
          print('[Download] Paired for chunk ${chunkInfo.chunkIndex}');
          onProgress?.call('Downloading chunk $chunkLabel...');
          break;
        } else if (type == 'waiting') {
          onProgress?.call('Waiting for peer · chunk $chunkLabel');
          print('[Download] Waiting for peer (chunk ${chunkInfo.chunkIndex})...');
        } else if (type == 'error') {
          throw Exception('peer error on chunk ${chunkInfo.chunkIndex}: ${msg['message']}');
        } else {
          print('[Download] Unexpected pairing message: $msg');
        }
      }

      // Collect binary frames until chunk_complete
      final binaryChunks = <Uint8List>[];
      while (true) {
        final frame = await session.next().timeout(_chunkTimeout);
        if (frame is _BinaryFrame) {
          binaryChunks.add(frame.data);
        } else if (frame is _JsonFrame) {
          final type = frame.data['type'] as String?;
          if (type == 'chunk_complete') {
            break;
          } else if (type == 'error') {
            throw Exception('peer error on chunk ${chunkInfo.chunkIndex}: ${frame.data['message']}');
          } else {
            print('[Download] Unexpected message during transfer: ${frame.data}');
          }
        }
      }

      final binaryData = binaryChunks.length == 1
          ? binaryChunks[0]
          : Uint8List.fromList(binaryChunks.expand((b) => b).toList());

      // Verify per-chunk hash
      final sha256 = Sha256();
      final computedHash = HEX.encode(
        (await sha256.hash(binaryData)).bytes,
      );
      if (computedHash != chunkInfo.chunkHash) {
        throw Exception(
            'Chunk ${chunkInfo.chunkIndex} hash mismatch\n'
            '  computed : $computedHash\n'
            '  expected : ${chunkInfo.chunkHash}');
      }

      print('[Download] Chunk ${chunkInfo.chunkIndex} verified (${binaryData.length} bytes)');
      return binaryData;
    } finally {
      session.dispose();
      await ws.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _toWsUrl(String relayUrl, String token, int chunkIndex) {
    String url = relayUrl;
    if (url.startsWith('https://')) {
      url = 'wss://${url.substring(8)}';
    } else if (url.startsWith('http://')) {
      url = 'ws://${url.substring(7)}';
    }
    return '$url/connect?token=$token&chunkIndex=$chunkIndex&role=client';
  }
}

// -----------------------------------------------------------------------------
// WebSocket session — handles interleaved JSON control messages and binary frames
// -----------------------------------------------------------------------------

sealed class _RelayFrame {}

final class _JsonFrame extends _RelayFrame {
  final Map<String, dynamic> data;
  _JsonFrame(this.data);
}

final class _BinaryFrame extends _RelayFrame {
  final Uint8List data;
  _BinaryFrame(this.data);
}

class _DownloadWsSession {
  final WebSocket _ws;
  final _buffer = <_RelayFrame>[];
  final _waiters = <Completer<_RelayFrame>>[];
  late final StreamSubscription<dynamic> _sub;

  _DownloadWsSession(this._ws) {
    _sub = _ws.listen(
      (data) {
        final _RelayFrame frame;
        if (data is String) {
          frame = _JsonFrame(jsonDecode(data) as Map<String, dynamic>);
        } else if (data is Uint8List) {
          frame = _BinaryFrame(data);
        } else {
          frame = _BinaryFrame(Uint8List.fromList(data as List<int>));
        }

        if (_waiters.isNotEmpty) {
          _waiters.removeAt(0).complete(frame);
        } else {
          _buffer.add(frame);
        }
      },
      onError: (Object e) {
        for (final w in _waiters) {
          w.completeError(e);
        }
        _waiters.clear();
      },
      onDone: () {
        final err = Exception('WebSocket closed unexpectedly');
        for (final w in _waiters) {
          w.completeError(err);
        }
        _waiters.clear();
      },
    );
  }

  void sendJson(Map<String, dynamic> msg) => _ws.add(jsonEncode(msg));

  Future<_RelayFrame> next() {
    if (_buffer.isNotEmpty) return Future.value(_buffer.removeAt(0));
    final c = Completer<_RelayFrame>();
    _waiters.add(c);
    return c.future;
  }

  Future<Map<String, dynamic>> nextJsonMessage() async {
    final frame = await next();
    if (frame is _JsonFrame) return frame.data;
    throw Exception(
        'Expected JSON message from relay but received a binary frame');
  }

  Future<Uint8List> nextBinaryMessage() async {
    final frame = await next();
    if (frame is _BinaryFrame) return frame.data;
    throw Exception(
        'Expected binary frame from relay but received JSON: ${(frame as _JsonFrame).data}');
  }

  void dispose() {
    _sub.cancel();
    _buffer.clear();
    _waiters.clear();
  }
}
