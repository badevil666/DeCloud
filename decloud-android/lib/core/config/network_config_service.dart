import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth/auth_service.dart';
import 'api_config_service.dart';

class NetworkConfig {
  final String escrowAddress;
  final String dcldTokenAddress;
  final int chainId;

  const NetworkConfig({
    required this.escrowAddress,
    required this.dcldTokenAddress,
    required this.chainId,
  });
}

/// Fetches live network config (contract addresses, chainId) from the backend.
/// Use this instead of compile-time blockchain_config.dart values whenever
/// the active network may differ from the build-time default.
class NetworkConfigService {
  static Future<NetworkConfig> fetch() async {
    final baseUrl = await ApiConfigService.getBaseUrl();
    final token   = await AuthService.getToken();
    if (token == null) throw Exception('Not authenticated.');

    final response = await http.get(
      Uri.parse('$baseUrl/client/network-config'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('network-config failed: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return NetworkConfig(
      escrowAddress:    (body['escrowAddress']    as String?) ?? '',
      dcldTokenAddress: (body['dcldTokenAddress'] as String?) ?? '',
      chainId:          int.tryParse((body['chainId'] as String?) ?? '') ?? 11155111,
    );
  }
}
