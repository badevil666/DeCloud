import '../storage/secure_storage.dart';
import 'blockchain_config.dart';

/// Persists user-configurable DCLD token and StorageEscrow addresses.
/// Falls back to compile-time defaults from blockchain_config.dart.
class ContractConfigService {
  static const _dcldKey   = 'dcld_token_address';
  static const _escrowKey = 'escrow_contract_address';

  static Future<String> getDcldAddress() async {
    return await SecureStorage.read(_dcldKey) ?? dcldTokenAddress;
  }

  static Future<String> getEscrowAddress() async {
    return await SecureStorage.read(_escrowKey) ?? escrowContractAddress;
  }

  static Future<void> setDcldAddress(String addr) async {
    await SecureStorage.write(_dcldKey, addr.trim());
  }

  static Future<void> setEscrowAddress(String addr) async {
    await SecureStorage.write(_escrowKey, addr.trim());
  }

  static Future<void> resetToDefault() async {
    await SecureStorage.delete(_dcldKey);
    await SecureStorage.delete(_escrowKey);
  }
}
