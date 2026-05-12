import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth/auth_service.dart';
import '../config/api_config_service.dart';

class ChunkPeerProof {
  final String peerAddress;
  final int intervalsVerified;
  final int intervalCount;
  final String status;

  const ChunkPeerProof({
    required this.peerAddress,
    required this.intervalsVerified,
    required this.intervalCount,
    required this.status,
  });

  factory ChunkPeerProof.fromJson(Map<String, dynamic> j) => ChunkPeerProof(
        peerAddress: (j['peerAddress'] as String?) ?? '',
        intervalsVerified: (j['intervalsVerified'] as int?) ?? 0,
        intervalCount: (j['intervalCount'] as int?) ?? 10,
        status: (j['status'] as String?) ?? 'UNKNOWN',
      );
}

class ChunkProof {
  final int chunkIndex;
  final List<ChunkPeerProof> peers;

  const ChunkProof({required this.chunkIndex, required this.peers});

  factory ChunkProof.fromJson(Map<String, dynamic> j) => ChunkProof(
        chunkIndex: (j['chunkIndex'] as int?) ?? 0,
        peers: (j['peers'] as List<dynamic>? ?? [])
            .map((e) => ChunkPeerProof.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ProofService {
  static Future<List<ChunkProof>> fetchProofs(String fileId) async {
    final baseUrl = await ApiConfigService.getBaseUrl();
    final token = await AuthService.getToken();
    if (token == null) throw Exception('Not authenticated.');

    final response = await http.get(
      Uri.parse('$baseUrl/client/files/$fileId/proofs'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final list = body['chunks'] as List<dynamic>? ?? [];
      return list
          .map((e) => ChunkProof.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (response.statusCode == 404) return [];
    throw Exception('fetchProofs failed: ${response.statusCode}');
  }
}
