import 'package:flutter/material.dart';
import '../../core/crypto/wallet_service.dart';
import '../../core/auth_notifier.dart';
import '../../widgets/mnemonic_backup_widget.dart';

class CreateWalletFlow extends StatefulWidget {
  const CreateWalletFlow({super.key});

  @override
  State<CreateWalletFlow> createState() => _CreateWalletFlowState();
}

class _CreateWalletFlowState extends State<CreateWalletFlow> {
  String? mnemonic;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _createWallet();
  }

  Future<void> _createWallet() async {
    final result = await WalletService.createWallet();
    setState(() {
      mnemonic = result.mnemonic;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Backup Recovery Phrase',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : MnemonicBackupWidget(
                mnemonic: mnemonic!,
                onConfirmed: () async {
                  mnemonic = null;
                  await AuthNotifier().login();
                  if (context.mounted) Navigator.pop(context);
                },
              ),
      ),
    );
  }
}
