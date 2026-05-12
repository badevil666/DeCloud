// This screen acts as a gate for the wallet functionality.
import 'package:flutter/material.dart';
import '../../core/auth_notifier.dart';
import './wallet_home_screen.dart';
import 'wallet_setup_screen.dart';

/// WalletGateScreen is a StatefulWidget that acts as a gateway for the wallet feature.
class WalletGateScreen extends StatefulWidget {
  const WalletGateScreen({super.key});

  @override
  State<WalletGateScreen> createState() => _WalletGateScreenState();
}

class _WalletGateScreenState extends State<WalletGateScreen> {
  final _authNotifier = AuthNotifier();

  @override
  void initState() {
    super.initState();
    _authNotifier.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    _authNotifier.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final walletExists = _authNotifier.walletAddress != null;

    return Scaffold(
      backgroundColor: Colors.black, // Sets the background color of the screen.
      body: Center(
        child: walletExists
            ? const WalletHomeScreen()
            : const WalletSetupScreen(),
      ),
    );
  }
}
