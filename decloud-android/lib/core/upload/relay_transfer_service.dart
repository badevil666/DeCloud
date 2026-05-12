import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'upload_models.dart';

class RelayTransferService {
  static const int _maxRetries = 3;
  static const _retryDelay = Duration(seconds: 2);
  static const _connectTimeout = Duration(seconds: 10);
  static const _pairTimeout = Duration(seconds: 60);
  static const _ackTimeout = Duration(seconds: 30);

  /// Transfers the assigned chunks to one peer via the relay.
  /// Retries up to 3 times on counterpart_left or timeout.
  static Future<void> transferToPeer({
    required String relayBaseUrl,
    required String peerToken,
    required List<int> chunkIndexes,
    required List<Uint8List> chunks,
    required List<ChunkInfo> chunkInfos,
  }) async {
    Exception? lastError;
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      if (attempt > 1) {
        print('[Relay] Retry $attempt/$_maxRetries in 2s...');
        await Future.delayed(_retryDelay);
      }
      try {
        await _runTransfer(relayBaseUrl, peerToken, chunkIndexes, chunks, chunkInfos);
        return;
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('counterpart_left') || e is TimeoutException) {
          print('[Relay] Retryable error on attempt $attempt: $e');
          lastError = e is Exception ? e : Exception(msg);
        } else {
          rethrow;
        }
      }
    }
    throw lastError ?? Exception('Transfer failed after $_maxRetries attempts');
  }

  static Future<void> _runTransfer(
    String relayBaseUrl,
    String peerToken,
    List<int> chunkIndexes,
    List<Uint8List> chunks,
    List<ChunkInfo> chunkInfos,
  ) async {
    final wsUrl = _toWsUrl(relayBaseUrl);
    print('[Relay] Connecting to $wsUrl (token: ${peerToken.substring(0, 8)}...)');

    final ws = await WebSocket.connect(wsUrl).timeout(_connectTimeout);
    final session = _WsSession(ws);
    try {
      // Step 1: Send pairing message
      session.sendJson({'token': peerToken, 'role': 'client'});
      print('[Relay] Pairing...');

      // Step 2: Wait for "paired" (skip "waiting" messages)
      while (true) {
        final msg = await session.nextMessage().timeout(_pairTimeout);
        final type = msg['type'] as String?;
        if (type == 'paired') {
          print('[Relay] Paired');
          break;
        } else if (type == 'waiting') {
          print('[Relay] Waiting for peer...');
        } else if (type == 'counterpart_left') {
          throw Exception('counterpart_left during pairing');
        } else {
          print('[Relay] Unexpected pairing message: $msg');
        }
      }

      // Step 3: Send each chunk sequentially
      for (final chunkIndex in chunkIndexes) {
        final data = chunks[chunkIndex];
        final info = chunkInfos[chunkIndex];
        print('[Relay] Sending chunk $chunkIndex (${data.length} bytes)');

        session.sendJson({
          'type': 'chunk_start',
          'chunkIndex': chunkIndex,
          'size': data.length,
          'hash': info.hash,
        });

        ws.add(data); // binary frame

        session.sendJson({'type': 'chunk_end', 'chunkIndex': chunkIndex});

        // Wait for ack
        while (true) {
          final msg = await session.nextMessage().timeout(_ackTimeout);
          final type = msg['type'] as String?;
          if (type == 'chunk_ack' && msg['chunkIndex'] == chunkIndex) {
            print('[Relay] Chunk $chunkIndex acked');
            break;
          } else if (type == 'counterpart_left') {
            throw Exception('counterpart_left waiting for chunk_ack $chunkIndex');
          } else {
            print('[Relay] Unexpected ack message: $msg');
          }
        }
      }

      // Step 4: Done
      session.sendJson({'type': 'transfer_complete'});
      print('[Relay] Transfer complete for token ${peerToken.substring(0, 8)}...');
    } finally {
      session.dispose();
      await ws.close();
    }
  }

  static String _toWsUrl(String baseUrl) {
    String url = baseUrl;
    if (url.startsWith('https://')) {
      url = 'wss://${url.substring(8)}';
    } else if (url.startsWith('http://')) {
      url = 'ws://${url.substring(7)}';
    }
    return '$url/connect';
  }
}

/// Wraps a [WebSocket] with a buffered message queue so callers can
/// await individual messages without losing interleaved frames.
class _WsSession {
  final WebSocket _ws;
  final _buffer = <Map<String, dynamic>>[];
  final _waiters = <Completer<Map<String, dynamic>>>[];
  late final StreamSubscription _sub;

  _WsSession(this._ws) {
    _sub = _ws.listen(
      (data) {
        if (data is! String) return; // ignore binary frames from relay
        final json = jsonDecode(data) as Map<String, dynamic>;
        if (_waiters.isNotEmpty) {
          _waiters.removeAt(0).complete(json);
        } else {
          _buffer.add(json);
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

  Future<Map<String, dynamic>> nextMessage() {
    if (_buffer.isNotEmpty) return Future.value(_buffer.removeAt(0));
    final c = Completer<Map<String, dynamic>>();
    _waiters.add(c);
    return c.future;
  }

  void dispose() {
    _sub.cancel();
    _buffer.clear();
    _waiters.clear();
  }
}
