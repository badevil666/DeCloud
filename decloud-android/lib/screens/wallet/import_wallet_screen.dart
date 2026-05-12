import 'package:flutter/material.dart';
import '../../core/crypto/wallet_service.dart';
import '../../core/auth_notifier.dart';
import '../../core/constants.dart';

class ImportWalletScreen extends StatefulWidget {
  const ImportWalletScreen({super.key});

  @override
  State<ImportWalletScreen> createState() => _ImportWalletScreenState();
}

class _ImportWalletScreenState extends State<ImportWalletScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _import() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await WalletService.importWallet(_controller.text.trim());
      await AuthNotifier().login();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      setState(() {
        _error = 'Invalid recovery phrase. Please check and try again.';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Connect Wallet',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Enter Recovery Phrase',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Paste your 12 or 24-word recovery phrase below, with words separated by spaces.',
                style: TextStyle(color: kTextSecondary, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: kCardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _error != null ? Colors.redAccent : kDividerColor,
                  ),
                ),
                child: TextField(
                  controller: _controller,
                  maxLines: 5,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.6,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'word1 word2 word3 ...',
                    hintStyle: TextStyle(color: kTextSecondary),
                    contentPadding: EdgeInsets.all(16),
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
              const Spacer(),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _import,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Connect Wallet',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
