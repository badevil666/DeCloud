import '../storage/secure_storage.dart';
import 'blockchain_config.dart';

/// Persists a user-configurable blockchain RPC URL.
/// Falls back to the compile-time [rpcUrl] from blockchain_config.dart when none is set.
class RpcConfigService {
  static const _key = 'blockchain_rpc_url';

  static Future<String> getRpcUrl() async {
    return await SecureStorage.read(_key) ?? rpcUrl;
  }

  static Future<void> setRpcUrl(String url) async {
    final trimmed = url.trim().replaceAll(RegExp(r'/+$'), '');
    await SecureStorage.write(_key, trimmed);
  }

  static Future<void> resetToDefault() async {
    await SecureStorage.delete(_key);
  }
}
