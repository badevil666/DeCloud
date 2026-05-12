import '../storage/secure_storage.dart';
import 'api_config.dart';

/// Persists a user-configurable API base URL.
/// Falls back to [apiBaseUrl] from api_config.dart when none is set.
class ApiConfigService {
  static const _urlKey = 'api_base_url';

  static Future<String> getBaseUrl() async {
    return await SecureStorage.read(_urlKey) ?? apiBaseUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    final trimmed = url.trim().replaceAll(RegExp(r'/+$'), ''); // strip trailing slashes
    await SecureStorage.write(_urlKey, trimmed);
  }

  static Future<void> resetToDefault() async {
    await SecureStorage.delete(_urlKey);
  }
}
