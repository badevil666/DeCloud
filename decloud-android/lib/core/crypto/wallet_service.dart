import 'package:web3dart/web3dart.dart';
import 'mnemonic_service.dart';
import '../storage/secure_storage.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:web3dart/crypto.dart';

class WalletService {
  // All keys written by the wallet — single source of truth for cleanup.
  static const _keyPrivateKey = 'wallet_private_key';
  static const _keyAddress    = 'wallet_address';
  static const _keyLoggedIn   = 'is_logged_in';
  static const _keyAuthToken  = 'auth_token';

  static Future<WalletCreationResult> createWallet() async {
    await disconnect(); // wipe any previous wallet first

    final mnemonic = MnemonicService.generateMnemonic();
    final privateKey = MnemonicService.derivePrivateKey(mnemonic);
    final address = privateKey.address;
    final privateKeyHex = bytesToHex(privateKey.privateKey, include0x: false);

    assert(privateKeyHex.length == 64);

    await SecureStorage.write(_keyPrivateKey, privateKeyHex);
    await SecureStorage.write(_keyAddress, address.hex);

    return WalletCreationResult(address: address, mnemonic: mnemonic);
  }

  static Future<EthereumAddress> importWallet(String mnemonic) async {
    if (!bip39.validateMnemonic(mnemonic)) {
      throw Exception('Invalid mnemonic');
    }

    await disconnect();

    final privateKey = MnemonicService.derivePrivateKey(mnemonic);
    final address = privateKey.address;
    final privateKeyHex = bytesToHex(privateKey.privateKey, include0x: false);

    assert(privateKeyHex.length == 64);

    await SecureStorage.write(_keyPrivateKey, privateKeyHex);
    await SecureStorage.write(_keyAddress, address.hex);

    return address;
  }

  static Future<EthereumAddress> importWalletFromPrivateKey(String rawKey) async {
    // Accept with or without 0x prefix
    final hex = rawKey.trim().replaceFirst(RegExp(r'^0x'), '');

    if (hex.length != 64 || !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(hex)) {
      throw Exception('Invalid private key — must be 64 hex characters.');
    }

    await disconnect();

    final privateKey = EthPrivateKey.fromHex(hex);
    final address = privateKey.address;

    await SecureStorage.write(_keyPrivateKey, hex);
    await SecureStorage.write(_keyAddress, address.hex);

    return address;
  }

  /// Removes every piece of wallet data from storage.
  static Future<void> disconnect() async {
    await SecureStorage.delete(_keyPrivateKey);
    await SecureStorage.delete(_keyAddress);
    await SecureStorage.delete(_keyLoggedIn);
    await SecureStorage.delete(_keyAuthToken);
  }
}

class WalletCreationResult {
  final EthereumAddress address;
  final String mnemonic;

  WalletCreationResult({required this.address, required this.mnemonic});
}
