import 'dart:convert';
import 'dart:isolate';
import 'package:http/http.dart' as http;
import '../auth/auth_service.dart';
import '../config/api_config_service.dart';
import '../config/relay_config_service.dart';
import 'file_processor.dart';
import 'relay_transfer_service.dart';
import 'upload_models.dart';

class UploadService {
  /// Full two-phase upload flow:
  /// 1. Process file in an isolate (build manifest + keep chunks in memory)
  /// 2. POST manifest to /client/upload (phase 1) → receive sessionId + peer assignments
  /// 3. POST /client/upload/confirm (phase 2) → finalize allocation
  /// 4. Transfer chunks to each confirmed peer concurrently via relay WebSocket
  static Future<void> upload({
    required String filePath,
    required int numberOfChunks,
    required int replicationFactor,
    required DateTime endDate,
    void Function(String)? onProgress,
  }) async {
    final baseUrl = await ApiConfigService.getBaseUrl();
    final relayUrl = await RelayConfigService.getBaseUrl();
    final token = await AuthService.getToken();
    if (token == null) throw Exception('Not authenticated. Please log in first.');

    // Step 1: Process file — with progress if callback provided, else in isolate
    print('[Upload] Processing file: $filePath');
    final ProcessResult result;
    if (onProgress != null) {
      result = await processFileWithProgress(
          filePath, numberOfChunks, replicationFactor, endDate, onProgress);
    } else {
      result = await Isolate.run(() =>
          processFile(filePath, numberOfChunks, replicationFactor, endDate));
    }
    print('[Upload] File processed — ${result.chunks.length} chunk(s)');

    // Step 2 (Phase 1): POST manifest → allocate peers
    onProgress?.call('manifest');
    print('[Upload] Phase 1 — POSTing manifest to $baseUrl/client/upload');
    final allocateResponse = await http.post(
      Uri.parse('$baseUrl/client/upload'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(result.manifest.toJson()),
    );

    if (allocateResponse.statusCode != 202) {
      throw Exception('Allocation failed: ${allocateResponse.statusCode} ${allocateResponse.body}');
    }

    final alloc = AllocateResponse.fromJson(
      jsonDecode(allocateResponse.body) as Map<String, dynamic>,
    );
    print('[Upload] Phase 1 OK — sessionId=${alloc.sessionId} fileId=${alloc.fileId} peers=${alloc.peers.length} expiresIn=${alloc.expiresIn}s');

    // Step 3 (Phase 2): Confirm the session → finalize registration
    onProgress?.call('confirming');
    print('[Upload] Phase 2 — confirming session ${alloc.sessionId}');
    ConfirmResponse confirmed;
    try {
      final confirmResponse = await http.post(
        Uri.parse('$baseUrl/client/upload/confirm'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'sessionId': alloc.sessionId}),
      );

      if (confirmResponse.statusCode != 201) {
        throw Exception('Confirm failed: ${confirmResponse.statusCode} ${confirmResponse.body}');
      }

      confirmed = ConfirmResponse.fromJson(
        jsonDecode(confirmResponse.body) as Map<String, dynamic>,
      );
      print('[Upload] Phase 2 OK — fileId=${confirmed.fileId} status=${confirmed.status}');
    } catch (e) {
      await cancel(baseUrl: baseUrl, token: token, sessionId: alloc.sessionId);
      rethrow;
    }

    // Step 4: Transfer chunks to each confirmed peer concurrently
    int completedPeers = 0;
    final totalPeers = confirmed.peers.length;
    onProgress?.call('peers:$totalPeers');

    await Future.wait(
      confirmed.peers.entries.map((entry) async {
        final peerId = entry.key;
        final assignment = entry.value;
        print('[Upload] Starting relay to peer $peerId — chunks ${assignment.chunkIndexes}');
        await RelayTransferService.transferToPeer(
          relayBaseUrl: relayUrl,
          peerToken: assignment.token,
          chunkIndexes: assignment.chunkIndexes,
          chunks: result.chunks,
          chunkInfos: result.manifest.chunkInfo,
        );
        completedPeers++;
        onProgress?.call('peer:$completedPeers:$totalPeers');
      }),
    );

    print('[Upload] All chunks delivered for file ${confirmed.fileId}');
  }

  /// Cancels a pending upload session so peers can free reserved space.
  /// Safe to call even if the session has already expired.
  static Future<void> cancel({
    required String baseUrl,
    required String token,
    required String sessionId,
  }) async {
    try {
      print('[Upload] Cancelling session $sessionId');
      await http.post(
        Uri.parse('$baseUrl/client/upload/cancel'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'sessionId': sessionId}),
      );
    } catch (e) {
      print('[Upload] Cancel request failed (ignored): $e');
    }
  }
}
