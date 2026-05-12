import 'dart:convert';

import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';
import 'package:http/http.dart' as http;

import '../config/blockchain_config.dart';
import '../config/api_config_service.dart';
import '../config/rpc_config_service.dart';
import '../config/contract_config_service.dart';
import 'erc20_abi.dart';

class TokenTransfer {
  final String txHash;
  final String from;
  final String to;
  final double amount;
  final int blockNumber;

  const TokenTransfer({
    required this.txHash,
    required this.from,
    required this.to,
    required this.amount,
    required this.blockNumber,
  });
}

class EthService {
  static DeployedContract _buildContract(String tokenAddr) {
    final address = EthereumAddress.fromHex(tokenAddr);
    return DeployedContract(ContractAbi.fromJson(erc20Abi, "DCLD"), address);
  }

  static Future<double> getTokenBalance(String walletAddress) async {
    final rpc      = await RpcConfigService.getRpcUrl();
    final tokenAddr = await ContractConfigService.getDcldAddress();
    print('[EthService] getTokenBalance  addr=$walletAddress  rpc=$rpc  token=$tokenAddr');
    final client   = Web3Client(rpc, Client());
    final contract = _buildContract(tokenAddr);
    final address  = EthereumAddress.fromHex(walletAddress);
    try {
      return await _fetchBalance(address, client, contract).timeout(const Duration(seconds: 10));
    } catch (e) {
      if (rpc == rpcUrl && fallbackRpcUrl != rpcUrl) {
        print('[EthService] Primary failed, falling back to: $fallbackRpcUrl');
        final fallback = Web3Client(fallbackRpcUrl, Client());
        return await _fetchBalance(address, fallback, contract).timeout(const Duration(seconds: 10));
      }
      rethrow;
    }
  }

  static Future<double> _fetchBalance(EthereumAddress address, Web3Client client, DeployedContract contract) async {
    final fnBalanceOf = contract.function("balanceOf");
    final fnDecimals  = contract.function("decimals");
    final List<dynamic> balanceResult = await client.call(
      contract: contract,
      function: fnBalanceOf,
      params: [address],
    );
    final List<dynamic> decimalsResult = await client.call(
      contract: contract,
      function: fnDecimals,
      params: [],
    );
    final BigInt rawBalance = balanceResult.first as BigInt;
    final int decimals = (decimalsResult.first as BigInt).toInt();
    final BigInt divisor = BigInt.from(10).pow(decimals);
    final double balance = rawBalance.toDouble() / divisor.toDouble();
    print('[EthService] Balance: $balance DCLD');
    return balance;
  }

  static Future<double> getEthBalance(String walletAddress) async {
    final rpc = await RpcConfigService.getRpcUrl();
    final client = Web3Client(rpc, Client());
    final address = EthereumAddress.fromHex(walletAddress);
    try {
      final wei = await client.getBalance(address).timeout(const Duration(seconds: 8));
      return wei.getInWei.toDouble() / 1e18;
    } catch (_) {
      if (rpc == rpcUrl && fallbackRpcUrl != rpcUrl) {
        final fallback = Web3Client(fallbackRpcUrl, Client());
        final wei = await fallback.getBalance(address).timeout(const Duration(seconds: 10));
        return wei.getInWei.toDouble() / 1e18;
      }
      rethrow;
    }
  }

  /// Fetches the 20 most recent DCLD Transfer events involving [walletAddress].
  static Future<List<TokenTransfer>> getRecentTransfers(String walletAddress) async {
    const transferTopic = '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef';
    final paddedAddress = '0x' + walletAddress.toLowerCase().replaceFirst('0x', '').padLeft(64, '0');
    final rpc = await RpcConfigService.getRpcUrl();

    // Fetch live DCLD address from backend so local/testnet mismatches don't silently return empty
    String tokenAddr;
    try {
      final cfg = await _fetchPublicNetworkConfig(rpc);
      tokenAddr = cfg ?? await ContractConfigService.getDcldAddress();
    } catch (_) {
      tokenAddr = await ContractConfigService.getDcldAddress();
    }

    final latestHex = await _getLatestBlockHex(rpc);
    final fromBlock  = _safeFromBlock(latestHex, 50000);

    final results = await Future.wait([
      _getLogs(rpc, tokenAddr, transferTopic, paddedAddress, isFrom: false, fromBlock: fromBlock),
      _getLogs(rpc, tokenAddr, transferTopic, paddedAddress, isFrom: true,  fromBlock: fromBlock),
    ]);

    const zeroAddr = '0x0000000000000000000000000000000000000000';
    final all = [...results[0], ...results[1]]
        .where((t) => t.from != zeroAddr) // exclude mints / faucet events
        .toList();
    all.sort((a, b) => b.blockNumber.compareTo(a.blockNumber));
    return all.take(20).toList();
  }

  /// Returns the live DCLD token address from the backend, or null on failure.
  static Future<String?> _fetchPublicNetworkConfig(String rpc) async {
    try {
      final apiBase = await ApiConfigService.getBaseUrl();
      final resp = await http.get(
        Uri.parse('$apiBase/network-config'),
      ).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        return body['dcldTokenAddress'] as String?;
      }
    } catch (_) {}
    return null;
  }

  static Future<String> _getLatestBlockHex(String rpc) async {
    final resp = await http.post(
      Uri.parse(rpc),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': 'eth_blockNumber', 'params': []}),
    ).timeout(const Duration(seconds: 8));
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return data['result'] as String;
  }

  // Clamps so fromBlock never goes negative (important on fresh Anvil with few blocks)
  static String _safeFromBlock(String hexBlock, int amount) {
    final latest = int.parse(hexBlock.replaceFirst('0x', ''), radix: 16);
    final from   = latest > amount ? latest - amount : 0;
    return '0x${from.toRadixString(16)}';
  }

  static Future<List<TokenTransfer>> _getLogs(
    String rpc,
    String tokenAddr,
    String transferTopic,
    String paddedAddress, {
    required bool isFrom,
    required String fromBlock,
  }) async {
    final topics = isFrom
        ? [transferTopic, paddedAddress]
        : [transferTopic, null, paddedAddress];

    final resp = await http.post(
      Uri.parse(rpc),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'eth_getLogs',
        'params': [{
          'address': tokenAddr,
          'fromBlock': fromBlock,
          'toBlock': 'latest',
          'topics': topics,
        }],
      }),
    ).timeout(const Duration(seconds: 10));

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final logs = (data['result'] as List?) ?? [];

    return logs.map((log) {
      final topics = log['topics'] as List;
      final from   = _topicToAddress(topics[1] as String);
      final to     = _topicToAddress(topics[2] as String);
      final rawValue = BigInt.parse((log['data'] as String).replaceFirst('0x', ''), radix: 16);
      final amount = rawValue.toDouble() / 1e18;
      final block  = int.parse((log['blockNumber'] as String).replaceFirst('0x', ''), radix: 16);
      return TokenTransfer(txHash: log['transactionHash'] as String, from: from, to: to, amount: amount, blockNumber: block);
    }).toList();
  }

  static String _topicToAddress(String topic) =>
      '0x${topic.substring(topic.length - 40)}';
}
