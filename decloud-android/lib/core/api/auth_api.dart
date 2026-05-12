import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config_service.dart';

/// Raw HTTP calls for the /client/login and /client/register endpoints.
class AuthApi {
  /// GET /client/login or /client/register
  /// Body: { "wallet_address": "..." }
  /// Response: { "nonce": "..." }
  static Future<String> getNonce({
    required String walletAddress,
    required bool isRegister,
  }) async {
    final path = isRegister ? '/client/register' : '/client/login';
    final base = Uri.parse(await ApiConfigService.getBaseUrl());
    final uri = base.replace(path: path);

    // http.get() doesn't support a body — use http.Request directly
    final request = http.Request('GET', uri)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'application/json'
      ..body = jsonEncode({'wallet_address': walletAddress});

    final streamed = await request.send().timeout(const Duration(seconds: 15));
    final response = await http.Response.fromStream(streamed);

    _assertOk(response, path);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['nonce'] as String;
  }

  /// POST /client/login — returns a JWT token string.
  static Future<String> login({
    required String walletAddress,
    required String nonce,
    required String signature,
  }) async {
    return _postAuth(
      path: '/client/login',
      walletAddress: walletAddress,
      nonce: nonce,
      signature: signature,
    );
  }

  /// POST /client/register — returns a JWT token string.
  static Future<String> register({
    required String walletAddress,
    required String nonce,
    required String signature,
  }) async {
    return _postAuth(
      path: '/client/register',
      walletAddress: walletAddress,
      nonce: nonce,
      signature: signature,
    );
  }

  static Future<String> _postAuth({
    required String path,
    required String walletAddress,
    required String nonce,
    required String signature,
  }) async {
    final base = Uri.parse(await ApiConfigService.getBaseUrl());
    final uri = base.replace(path: path);

    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'wallet_address': walletAddress,
            'nonce': nonce,
            'signature': signature,
          }),
        )
        .timeout(const Duration(seconds: 15));

    _assertOk(response, path);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['token'] as String;
  }

  static void _assertOk(http.Response response, String path) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthApiException(
        path: path,
        statusCode: response.statusCode,
        message: _parseError(response.body),
      );
    }
  }

  static String _parseError(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['message']?.toString() ?? json['error']?.toString() ?? body;
    } catch (_) {
      return body;
    }
  }
}

class AuthApiException implements Exception {
  final String path;
  final int statusCode;
  final String message;

  const AuthApiException({
    required this.path,
    required this.statusCode,
    required this.message,
  });

  @override
  String toString() => 'AuthApiException($statusCode) on $path: $message';
}
