import 'dart:convert';
import 'dart:typed_data';
import 'package:web3dart/web3dart.dart';
import 'package:web3dart/crypto.dart'; // bytesToHex
import '../api/auth_api.dart';
import '../storage/secure_storage.dart';

/// Orchestrates the sign-in-with-Ethereum flow:
///   1. Fetch nonce from server
///   2. Sign it with the wallet private key (EIP-191 personal_sign)
///   3. POST credentials to server and receive a JWT
///   4. Persist the JWT in secure storage
class AuthService {
  static const _tokenKey = 'auth_token';

  /// Logs in with an existing account. Throws [AuthApiException] on failure.
  static Future<void> login(String privateKeyHex) async {
    await _authenticate(privateKeyHex: privateKeyHex, isRegister: false);
  }

  /// Registers a new account. Throws [AuthApiException] on failure.
  static Future<void> register(String privateKeyHex) async {
    await _authenticate(privateKeyHex: privateKeyHex, isRegister: true);
  }

  /// Returns the stored JWT, or null if not authenticated.
  static Future<String?> getToken() async {
    return SecureStorage.read(_tokenKey);
  }

  /// Deletes the stored JWT (does not touch wallet keys).
  static Future<void> clearToken() async {
    await SecureStorage.delete(_tokenKey);
  }

  // ── internals ─────────────────────────────────────────────────────────────

  static Future<void> _authenticate({
    required String privateKeyHex,
    required bool isRegister,
  }) async {
    // Derive the address from the private key — guarantees the address in the
    // request body is always the one that owns the signing key.
    final privateKey = EthPrivateKey.fromHex(privateKeyHex);
    final walletAddress = privateKey.address.hexEip55;

    final nonce = await AuthApi.getNonce(
      walletAddress: walletAddress,
      isRegister: isRegister,
    );

    final signature = await _personalSign(privateKeyHex, nonce);

    final token = isRegister
        ? await AuthApi.register(
            walletAddress: walletAddress,
            nonce: nonce,
            signature: signature,
          )
        : await AuthApi.login(
            walletAddress: walletAddress,
            nonce: nonce,
            signature: signature,
          );

    await SecureStorage.write(_tokenKey, token);
  }

  /// EIP-191 personal_sign:
  ///   keccak256("\x19Ethereum Signed Message:\n" + len(msg) + msg)
  /// Returns the 65-byte signature as a 0x-prefixed hex string.
  ///
  /// In this version of web3dart, EthPrivateKey.sign() returns
  /// Future<Uint8List> with layout: r[0..31] + s[32..63] + v[64].
  /// EIP-191 personal_sign matching ethers.js verifyMessage:
  ///   hash = keccak256("\x19Ethereum Signed Message:\n" + len(msg) + msg)
  ///   sign(hash)
  ///
  /// web3dart's sign() hashes its input again by default (isHash: false).
  /// We pass isHash: true so it treats our pre-computed hash as the final
  /// digest to sign — preventing the double-keccak256 bug.
  /// EIP-191 personal_sign matching ethers.js verifyMessage.
  /// web3dart's sign() applies keccak256 to the payload internally,
  /// so we pass the raw prefixed bytes and let it hash once.
  static Future<String> _personalSign(String privateKeyHex, String message) async {
    final msgBytes = Uint8List.fromList(utf8.encode(message));
    final prefix = '\x19Ethereum Signed Message:\n${msgBytes.length}';
    final prefixBytes = Uint8List.fromList(utf8.encode(prefix));

    // Pass un-hashed — web3dart applies keccak256 once internally
    final data = Uint8List.fromList([...prefixBytes, ...msgBytes]);

    final privateKey = EthPrivateKey.fromHex(privateKeyHex);
    final sigBytes = await privateKey.sign(data);

    // Ensure v is 27 or 28 (EIP-155)
    final mutable = List<int>.from(sigBytes);
    if (mutable[64] < 27) mutable[64] += 27;

    return '0x${bytesToHex(Uint8List.fromList(mutable))}';
  }
}
