import 'dart:convert';
import 'dart:typed_data';

import 'package:hex/hex.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';

import '../auth/auth_service.dart';
import '../config/api_config_service.dart';
import '../storage/secure_storage.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class PendingDeal {
  final String dealId;
  final String fileId;
  final String peerId;
  final String peerAddress;
  final String clientAddress;
  final String sizeBytes;
  final String durationBlocks;
  final String priceWei;
  final String peerEscrowWei;
  final List<String> chunkHashes;
  final String merkleRoot;
  final String fileIdBytes32;
  final String status;
  final bool clientSigned;
  final bool peerSigned;
  // Domain params injected from the API response (not blockchain_config.dart)
  final String escrowAddress;
  final int chainId;

  const PendingDeal({
    required this.dealId,
    required this.fileId,
    required this.peerId,
    required this.peerAddress,
    required this.clientAddress,
    required this.sizeBytes,
    required this.durationBlocks,
    required this.priceWei,
    required this.peerEscrowWei,
    required this.chunkHashes,
    required this.merkleRoot,
    required this.fileIdBytes32,
    required this.status,
    required this.clientSigned,
    required this.peerSigned,
    required this.escrowAddress,
    required this.chainId,
  });

  factory PendingDeal.fromJson(Map<String, dynamic> j, {String escrowAddress = '', int chainId = 11155111}) {
    final rawHashes = j['chunkHashes'];
    final List<String> hashes = rawHashes is List
        ? rawHashes.map((e) => e.toString()).toList()
        : (rawHashes is String ? List<String>.from(jsonDecode(rawHashes) as List) : []);

    return PendingDeal(
      dealId:         j['dealId']        as String,
      fileId:         (j['fileId']        as String?) ?? '',
      peerId:         (j['peerId']        as String?) ?? '',
      peerAddress:    (j['peerAddress']   as String?) ?? '',
      clientAddress:  (j['clientAddress'] as String?) ?? '',
      sizeBytes:      (j['sizeBytes']     as String?) ?? '0',
      durationBlocks: (j['durationBlocks'] as String?) ?? '0',
      priceWei:       (j['priceWei']      as String?) ?? '0',
      peerEscrowWei:  (j['peerEscrowWei'] as String?) ?? '0',
      chunkHashes:    hashes,
      merkleRoot:     (j['merkleRoot']    as String?) ?? '',
      fileIdBytes32:  (j['fileIdBytes32'] as String?) ?? '',
      status:         (j['status']        as String?) ?? 'UNKNOWN',
      clientSigned:   j['clientSigned']  as bool? ?? false,
      peerSigned:     j['peerSigned']    as bool? ?? false,
      escrowAddress:  escrowAddress,
      chainId:        chainId,
    );
  }
}

// ─── Service ──────────────────────────────────────────────────────────────────

class DealService {
  /// Fetch all deals for this client (newest first, max 50).
  static Future<List<PendingDeal>> fetchAllDeals() async {
    final baseUrl = await ApiConfigService.getBaseUrl();
    final token   = await AuthService.getToken();
    if (token == null) throw Exception('Not authenticated.');
    final response = await http.get(
      Uri.parse('$baseUrl/client/deals'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final body         = jsonDecode(response.body) as Map<String, dynamic>;
      final escrowAddr   = (body['escrowAddress'] as String?) ?? '';
      final chainIdVal   = int.tryParse((body['chainId'] as String?) ?? '') ?? 11155111;
      final list         = body['deals'] as List<dynamic>;
      return list
          .map((e) => PendingDeal.fromJson(e as Map<String, dynamic>,
              escrowAddress: escrowAddr, chainId: chainIdVal))
          .toList();
    } else {
      throw Exception('fetchAllDeals failed: ${response.statusCode}');
    }
  }

  /// Fetch all pending deals for [fileId] that need the client's signature.
  static Future<List<PendingDeal>> fetchDealsForFile(String fileId) async {
    final baseUrl = await ApiConfigService.getBaseUrl();
    final token   = await AuthService.getToken();
    if (token == null) throw Exception('Not authenticated.');

    final response = await http.get(
      Uri.parse('$baseUrl/client/files/$fileId/deals'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final body       = jsonDecode(response.body) as Map<String, dynamic>;
      final escrowAddr = (body['escrowAddress'] as String?) ?? '';
      final chainIdVal = int.tryParse((body['chainId'] as String?) ?? '') ?? 11155111;
      final list       = body['deals'] as List<dynamic>;
      return list
          .map((e) => PendingDeal.fromJson(e as Map<String, dynamic>,
              escrowAddress: escrowAddr, chainId: chainIdVal))
          .where((d) => !d.clientSigned)
          .toList();
    } else if (response.statusCode == 404) {
      return [];
    } else {
      throw Exception('fetchDealsForFile failed: ${response.statusCode} ${response.body}');
    }
  }

  /// Sign and submit the client's EIP-712 signature for [deal].
  static Future<void> signAndSubmitDeal(PendingDeal deal) async {
    final privateKeyHex = await SecureStorage.read('wallet_private_key');
    if (privateKeyHex == null) throw Exception('No wallet private key found.');

    final token = await AuthService.getToken();
    if (token == null) throw Exception('Not authenticated.');

    final signature = await _signDealEip712(privateKeyHex, deal);

    final baseUrl  = await ApiConfigService.getBaseUrl();
    final response = await http.post(
      Uri.parse('$baseUrl/client/deals/${deal.dealId}/sign'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type':  'application/json',
      },
      body: jsonEncode({'signature': signature}),
    );

    if (response.statusCode != 200) {
      throw Exception('signAndSubmitDeal failed: ${response.statusCode} ${response.body}');
    }
  }

  /// Retry a single FAILED deal by calling POST /client/deals/:dealId/retry.
  static Future<void> retryDeal(String dealId) async {
    final baseUrl = await ApiConfigService.getBaseUrl();
    final token   = await AuthService.getToken();
    if (token == null) throw Exception('Not authenticated.');

    final response = await http.post(
      Uri.parse('$baseUrl/client/deals/$dealId/retry'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('retryDeal failed: ${response.statusCode} ${response.body}');
    }
  }

  /// Retry all FAILED deals for [fileId], then auto-sign any that become signable.
  /// Logs errors but does not throw.
  static Future<void> retryFailedDealsForFile(String fileId) async {
    List<PendingDeal> allDeals;
    try {
      allDeals = await fetchAllDeals();
    } catch (e) {
      print('[DealService] fetchAllDeals error during retry for $fileId: $e');
      return;
    }

    final failed = allDeals.where((d) => d.fileId == fileId && d.status == 'FAILED').toList();
    if (failed.isEmpty) return;

    for (final deal in failed) {
      try {
        await retryDeal(deal.dealId);
        print('[DealService] Queued retry for deal ${deal.dealId.substring(0, 12)}…');
      } catch (e) {
        print('[DealService] Retry request failed for ${deal.dealId.substring(0, 12)}…: $e');
      }
    }

    // Give the peer a moment to receive the WS notification and sign
    await Future.delayed(const Duration(seconds: 2));
    await autoSignDealsForFile(fileId);
  }

  /// Auto-sign all unsigned deals for [fileId] silently in the background.
  /// Logs errors but does not throw.
  static Future<void> autoSignDealsForFile(String fileId) async {
    List<PendingDeal> deals;
    try {
      deals = await fetchDealsForFile(fileId);
    } catch (e) {
      print('[DealService] fetchDealsForFile error for $fileId: $e');
      return;
    }

    for (final deal in deals) {
      try {
        await signAndSubmitDeal(deal);
        print('[DealService] Signed deal ${deal.dealId.substring(0, 12)}… for file $fileId');
      } catch (e) {
        print('[DealService] Failed to sign deal ${deal.dealId.substring(0, 12)}…: $e');
      }
    }
  }

  // ─── EIP-712 signing ───────────────────────────────────────────────────────

  /// Build the EIP-712 digest for a StorageEscrow Deal and sign it.
  ///
  /// Domain: name="StorageEscrow", version="1", chainId=11155111, verifyingContract=escrowAddress
  ///
  /// Struct hash:
  ///   keccak256(abi.encode(
  ///     TYPEHASH,
  ///     dealId, fileId, merkleRoot,
  ///     client, peer,
  ///     size, duration, price, peerEscrowAmount,
  ///     keccak256(abi.encodePacked(chunkHashes))
  ///   ))
  ///
  /// Final digest: keccak256("\x19\x01" || domainSeparator || structHash)
  static Future<String> _signDealEip712(
    String privateKeyHex,
    PendingDeal deal,
  ) async {
    final chainIdBig = deal.chainId;
    final escrow     = deal.escrowAddress;

    // ── Domain separator ──────────────────────────────────────────────────────
    final domainTypeHash = keccak256(Uint8List.fromList(utf8.encode(
      'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)',
    )));

    final domainSeparator = keccak256(_abiEncode([
      _bytes32(domainTypeHash),
      _bytes32(keccak256(Uint8List.fromList(utf8.encode('StorageEscrow')))),
      _bytes32(keccak256(Uint8List.fromList(utf8.encode('1')))),
      _uint256(BigInt.from(chainIdBig)),
      _address(escrow),
    ]));

    // ── Struct hash ───────────────────────────────────────────────────────────
    final dealTypeHash = keccak256(Uint8List.fromList(utf8.encode(
      'Deal(bytes32 dealId,bytes32 fileId,bytes32 merkleRoot,'
      'address client,address peer,'
      'uint256 size,uint256 duration,uint256 price,uint256 peerEscrowAmount,'
      'bytes32[] chunkHashes)',
    )));

    // chunkHashes array encoded as keccak256(abi.encodePacked(hashes))
    final chunkHashesEncoded = deal.chunkHashes.isEmpty
        ? Uint8List(0)
        : Uint8List.fromList(
            deal.chunkHashes.expand((h) => _hexToBytes32(h)).toList(),
          );
    final chunkHashesHash = keccak256(chunkHashesEncoded);

    final structHash = keccak256(_abiEncode([
      _bytes32(dealTypeHash),
      _hexToBytes32(deal.dealId),
      _hexToBytes32(deal.fileIdBytes32),
      _hexToBytes32(deal.merkleRoot),
      _address(deal.clientAddress),
      _address(deal.peerAddress),
      _uint256(BigInt.parse(deal.sizeBytes)),
      _uint256(BigInt.parse(deal.durationBlocks)),
      _uint256(BigInt.parse(deal.priceWei)),
      _uint256(BigInt.parse(deal.peerEscrowWei)),
      _bytes32(chunkHashesHash),
    ]));

    // ── Final digest ──────────────────────────────────────────────────────────
    final digest = keccak256(Uint8List.fromList([
      0x19, 0x01,
      ...domainSeparator,
      ...structHash,
    ]));

    // ── Sign raw digest using web3dart/crypto.dart sign() ────────────────────
    // crypto.sign() treats its input as the final digest — no extra keccak256.
    final privateKeyBigInt = EthPrivateKey.fromHex(privateKeyHex).privateKeyInt;
    final privateKeyBytes  = Uint8List.fromList(
      HEX.decode(privateKeyBigInt.toRadixString(16).padLeft(64, '0')),
    );
    final sig    = sign(digest, privateKeyBytes);
    final rBytes = HEX.decode(sig.r.toRadixString(16).padLeft(64, '0'));
    final sBytes = HEX.decode(sig.s.toRadixString(16).padLeft(64, '0'));
    final vByte  = sig.v < 27 ? sig.v + 27 : sig.v;
    final sigBytes = [...rBytes, ...sBytes, vByte];

    return '0x${HEX.encode(sigBytes)}';
  }

  // ─── ABI encoding helpers ─────────────────────────────────────────────────

  static Uint8List _abiEncode(List<Uint8List> parts) =>
      Uint8List.fromList(parts.expand((p) => p).toList());

  static Uint8List _bytes32(Uint8List data) {
    assert(data.length == 32);
    return data;
  }

  static Uint8List _uint256(BigInt value) {
    final hex = value.toRadixString(16).padLeft(64, '0');
    return Uint8List.fromList(HEX.decode(hex));
  }

  static Uint8List _address(String addr) {
    // Addresses are left-padded to 32 bytes (12 zero bytes + 20 address bytes)
    final hex = addr.replaceFirst('0x', '').toLowerCase().padLeft(64, '0');
    return Uint8List.fromList(HEX.decode(hex));
  }

  static Uint8List _hexToBytes32(String hex) {
    final clean = hex.replaceFirst('0x', '').padLeft(64, '0');
    return Uint8List.fromList(HEX.decode(clean));
  }
}
