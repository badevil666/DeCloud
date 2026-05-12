import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/crypto/eth_service.dart';
import '../../core/auth_notifier.dart';
import '../../core/deals/deal_service.dart';

// SecureStorage key for auto-sign preference
const _kAutoSignKey = 'auto_sign_deals';

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

enum WalletSection { transactions, contracts }

class _WalletHomeScreenState extends State<WalletHomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  String? address;
  double balance = 0.0;
  double ethBalance = 0.0;
  double maxBalance = 10.0;
  bool loading = true;
  bool _balanceFailed = false;
  bool _balanceLoading = false;
  bool _addressCopied = false;

  WalletSection _activeSection = WalletSection.transactions;

  final _txKey = GlobalKey<_TransactionsSectionState>();
  final _contractKey = GlobalKey<_ContractsSectionState>();

  Future<void> _handleRefresh() async {
    setState(() => _balanceFailed = false);
    _loadWalletData();
    if (_activeSection == WalletSection.transactions) {
      await _txKey.currentState?._load();
    } else {
      await _contractKey.currentState?._load();
    }
  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    print('[WalletHome] _loadWalletData started');

    final addr = await SecureStorage.read('wallet_address');
    print('[WalletHome] wallet_address from storage: $addr');

    if (addr == null) {
      if (mounted) {
        setState(() {
          address = '';
          loading = false;
        });
      }
      return;
    }

    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) setState(() => _balanceLoading = true);

    double realBalance = 0.0;
    double realEthBalance = 0.0;
    bool failed = false;
    try {
      print('[WalletHome] Fetching balances for $addr...');
      realBalance    = await EthService.getTokenBalance(addr);
      realEthBalance = await EthService.getEthBalance(addr);
      print('[WalletHome] DCLD: $realBalance  ETH: $realEthBalance');
    } catch (e, st) {
      print('[WalletHome] Failed to fetch balance: $e\n$st');
      failed = true;
    }

    if (!mounted) return;

    setState(() {
      address       = addr;
      balance       = realBalance;
      ethBalance    = realEthBalance;
      _balanceFailed  = failed;
      _balanceLoading = false;
      loading    = false;
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildSectionSwitcher() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _sectionButton(
            label: "Transactions",
            selected: _activeSection == WalletSection.transactions,
            onTap: () => setState(() => _activeSection = WalletSection.transactions),
          ),
          _sectionButton(
            label: "Smart Contracts",
            selected: _activeSection == WalletSection.contracts,
            onTap: () => setState(() => _activeSection = WalletSection.contracts),
          ),
        ],
      ),
    );
  }

  Widget _sectionButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.black : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _handleRefresh,
                color: Colors.cyanAccent,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          "Wallet",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: Color.fromARGB(200, 200, 200, 200),
                          ),
                        ),
                        const SizedBox(height: 15),
                        AnimatedBuilder(
                          animation: _controller,
                          builder: (context, child) {
                            final scale = Curves.easeOutBack.transform(
                              _controller.value.clamp(0.0, 1.0),
                            );
                            return Transform.scale(
                              scale: scale,
                              alignment: Alignment.topCenter,
                              child: child,
                            );
                          },
                          child: _walletCard(),
                        ),
                        const SizedBox(height: 10),
                        _buildSectionSwitcher(),
                        const SizedBox(height: 10),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _activeSection == WalletSection.transactions
                              ? _TransactionsSection(key: _txKey)
                              : _ContractsSection(key: _contractKey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _walletCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: kPrimaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 249, 249, 249).withAlpha(200),
            blurRadius: 20,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Wallet Address",
            style: TextStyle(
              color: Color.fromARGB(179, 2, 1, 1),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 1),
          GestureDetector(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: address!));
              setState(() => _addressCopied = true);
              await Future.delayed(const Duration(seconds: 2));
              if (mounted) setState(() => _addressCopied = false);
            },
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    address!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  _addressCopied ? Icons.check_rounded : Icons.copy_rounded,
                  color: Colors.white70,
                  size: 16,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Wallet Balance",
            style: TextStyle(
              color: Color.fromARGB(179, 10, 9, 9),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 1),
          if (_balanceLoading)
            const SizedBox(
              height: 28,
              width: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          else if (_balanceFailed)
            Row(
              children: [
                const Icon(Icons.wifi_off_rounded, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Could not load balance',
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _loadWalletData,
                  child: const Text(
                    'Retry',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white,
                    ),
                  ),
                ),
              ],
            )
          else
            Text(
              '${balance.toStringAsFixed(4)} DCLD',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 4),
          if (!_balanceFailed && !_balanceLoading)
            Text(
              '${ethBalance.toStringAsFixed(6)} ETH (Sepolia)',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF181A20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: const Text(
                        'Disconnect Wallet',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                      content: const Text(
                        'Are you sure you want to disconnect? You will need your recovery phrase to reconnect.',
                        style: TextStyle(color: Colors.white70, height: 1.4),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text(
                            'Disconnect',
                            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await AuthNotifier().disconnectWallet();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white24,
                  elevation: 0,
                  shape: const StadiumBorder(),
                ),
                child: const Text(
                  "Disconnect",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  elevation: 0,
                  shape: const StadiumBorder(),
                ),
                child: const Text(
                  "Send Tokens",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionsSection extends StatefulWidget {
  const _TransactionsSection({super.key});

  @override
  State<_TransactionsSection> createState() => _TransactionsSectionState();
}

class _TransactionsSectionState extends State<_TransactionsSection> {
  List<TokenTransfer>? _transfers;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final address = await SecureStorage.read('wallet_address');
      if (address == null) {
        if (mounted) setState(() { _transfers = []; _loading = false; });
        return;
      }
      final transfers = await EthService.getRecentTransfers(address);
      if (mounted) setState(() { _transfers = transfers; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        key: ValueKey("transactions"),
        padding: EdgeInsets.only(top: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        key: const ValueKey("transactions"),
        padding: const EdgeInsets.only(top: 16),
        child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
      );
    }
    if (_transfers == null || _transfers!.isEmpty) {
      return const Padding(
        key: ValueKey("transactions"),
        padding: EdgeInsets.only(top: 32),
        child: Center(child: Text("No DCLD transfers yet.", style: TextStyle(color: Colors.white70))),
      );
    }

    return Column(
      key: const ValueKey("transactions"),
      children: _transfers!.map((t) => _TransactionTile(transfer: t)).toList(),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final TokenTransfer transfer;

  const _TransactionTile({required this.transfer});

  @override
  Widget build(BuildContext context) {
    // Determine direction from the current wallet address (loaded async, use FutureBuilder inline)
    return FutureBuilder<String?>(
      future: SecureStorage.read('wallet_address'),
      builder: (context, snap) {
        final myAddress = snap.data?.toLowerCase() ?? '';
        final incoming = transfer.to.toLowerCase() == myAddress;
        final counterparty = incoming ? transfer.from : transfer.to;
        final shortAddr = counterparty.length >= 10
            ? '${counterparty.substring(0, 6)}…${counterparty.substring(counterparty.length - 4)}'
            : counterparty;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: incoming ? Colors.green : Colors.red,
                child: Icon(
                  incoming ? Icons.call_received : Icons.call_made,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incoming ? "Received" : "Sent",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      shortAddr,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                "${incoming ? '+' : '-'}${transfer.amount.toStringAsFixed(4)} DCLD",
                style: TextStyle(
                  color: incoming ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ContractsSection extends StatefulWidget {
  const _ContractsSection({super.key});

  @override
  State<_ContractsSection> createState() => _ContractsSectionState();
}

class _ContractsSectionState extends State<_ContractsSection> {
  List<PendingDeal> _deals = [];
  bool _loading = true;
  String? _error;
  bool _autoSign = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadAutoSignPref();
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAutoSignPref() async {
    final val = await SecureStorage.read(_kAutoSignKey);
    if (mounted) setState(() => _autoSign = val != 'false');
  }

  Future<void> _toggleAutoSign(bool value) async {
    await SecureStorage.write(_kAutoSignKey, value ? 'true' : 'false');
    if (mounted) setState(() => _autoSign = value);
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final deals = await DealService.fetchAllDeals();
      if (mounted) setState(() { _deals = deals; _loading = false; });

      if (_autoSign) {
        // Sign any deals that still need the client's signature
        final unsigned = deals.where((d) =>
          (d.status == 'PENDING' || d.status == 'PEER_SIGNED') && !d.clientSigned
        ).toList();
        for (final deal in unsigned) {
          try {
            await DealService.signAndSubmitDeal(deal);
          } catch (_) {}
        }
        if (unsigned.isNotEmpty) _load();
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey("contracts"),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Auto-sign toggle
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Auto-sign deals",
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Switch(
                value: _autoSign,
                onChanged: _toggleAutoSign,
                activeThumbColor: Colors.blueAccent,
                activeTrackColor: Colors.blueAccent.withAlpha(120),
              ),
            ],
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          )
        else if (_deals.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(child: Text("No storage deals yet.", style: TextStyle(color: Colors.white70))),
          )
        else
          ..._deals.map((d) => _DealTile(
            deal: d,
            showSignButton: !_autoSign,
            onSigned: _load,
          )),
      ],
    );
  }
}

class _DealTile extends StatefulWidget {
  final PendingDeal deal;
  final bool showSignButton;
  final VoidCallback? onSigned;

  const _DealTile({required this.deal, this.showSignButton = false, this.onSigned});

  @override
  State<_DealTile> createState() => _DealTileState();
}

class _DealTileState extends State<_DealTile> {
  bool _signing = false;

  Color _statusColor(String s) {
    switch (s) {
      case 'SETTLED':    return Colors.greenAccent;
      case 'SUBMITTING': return Colors.blueAccent;
      case 'FAILED':     return Colors.redAccent;
      case 'EXPIRED':    return Colors.orange;
      default:           return Colors.white54;
    }
  }

  Future<void> _sign() async {
    setState(() => _signing = true);
    try {
      await DealService.signAndSubmitDeal(widget.deal);
      widget.onSigned?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _signing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deal = widget.deal;
    final priceEth = (BigInt.tryParse(deal.priceWei) ?? BigInt.zero).toDouble() / 1e18;
    final escrowEth = (BigInt.tryParse(deal.peerEscrowWei) ?? BigInt.zero).toDouble() / 1e18;
    final canSign = widget.showSignButton &&
        !deal.clientSigned &&
        (deal.status == 'PENDING' || deal.status == 'PEER_SIGNED');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Deal ${deal.dealId.length > 10 ? deal.dealId.substring(2, 10) : deal.dealId}…',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(deal.status).withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _statusColor(deal.status).withAlpha(100)),
                ),
                child: Text(
                  deal.status,
                  style: TextStyle(color: _statusColor(deal.status), fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Peer: ${deal.peerAddress.length > 10 ? '${deal.peerAddress.substring(0, 10)}…' : deal.peerAddress}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${priceEth.toStringAsFixed(6)} DCLD', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('Escrow: ${escrowEth.toStringAsFixed(6)} DCLD', style: const TextStyle(color: Colors.blueAccent, fontSize: 11)),
                ],
              ),
              Row(
                children: [
                  Icon(deal.clientSigned ? Icons.check_circle_outline : Icons.radio_button_unchecked,
                      color: deal.clientSigned ? Colors.greenAccent : Colors.white38, size: 14),
                  const SizedBox(width: 4),
                  const Text('You', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(width: 8),
                  Icon(deal.peerSigned ? Icons.check_circle_outline : Icons.radio_button_unchecked,
                      color: deal.peerSigned ? Colors.greenAccent : Colors.white38, size: 14),
                  const SizedBox(width: 4),
                  const Text('Peer', style: TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ],
          ),
          if (canSign) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton(
                onPressed: _signing ? null : _sign,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _signing
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Ink(
                        decoration: BoxDecoration(
                          gradient: kPrimaryGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text('Sign Deal', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
