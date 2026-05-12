import '../storage/secure_storage.dart';
import 'relay_config.dart';

/// Persists a user-configurable relay server base URL.
/// Falls back to [relayBaseUrl] from relay_config.dart when none is set.
class RelayConfigService {
  static const _urlKey = 'relay_base_url';

  static Future<String> getBaseUrl() async {
    return await SecureStorage.read(_urlKey) ?? relayBaseUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    final trimmed = url.trim().replaceAll(RegExp(r'/+$'), '');
    await SecureStorage.write(_urlKey, trimmed);
  }

  static Future<void> resetToDefault() async {
    await SecureStorage.delete(_urlKey);
  }
}
