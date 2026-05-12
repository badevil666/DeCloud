import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth/auth_service.dart';
import '../config/api_config_service.dart';
import 'file_record.dart';

class FilesService {
  static Future<List<FileRecord>> getFiles() async {
    final baseUrl = await ApiConfigService.getBaseUrl();
    final token = await AuthService.getToken();
    if (token == null) throw Exception('Not authenticated.');

    final response = await http.get(
      Uri.parse('$baseUrl/client/files'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load files: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final list = data['files'] as List<dynamic>;
    return list.map((e) => FileRecord.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> deleteFile(String fileId) async {
    final baseUrl = await ApiConfigService.getBaseUrl();
    final token = await AuthService.getToken();
    if (token == null) throw Exception('Not authenticated.');

    final response = await http.delete(
      Uri.parse('$baseUrl/client/files/$fileId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Delete failed: ${response.statusCode} ${response.body}');
    }
  }
}
