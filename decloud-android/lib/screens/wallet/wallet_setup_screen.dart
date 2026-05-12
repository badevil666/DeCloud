import 'package:flutter/material.dart';
import '../../core/constants.dart';
import './create_wallet_screen.dart';
import './import_wallet_screen.dart';

class WalletSetupScreen extends StatelessWidget {
  const WalletSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              const Icon(
                Icons.account_balance_wallet_rounded,
                size: 64,
                color: Colors.white,
              ),
              const SizedBox(height: 20),
              const Text(
                'Your Wallet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Create a new wallet or connect an existing one\nwith your recovery phrase.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kTextSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              _WalletOptionCard(
                icon: Icons.add_circle_outline_rounded,
                title: 'Create Wallet',
                subtitle: 'Generate a brand new wallet with a recovery phrase.',
                useGradient: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateWalletFlow()),
                ),
              ),
              const SizedBox(height: 16),
              _WalletOptionCard(
                icon: Icons.link_rounded,
                title: 'Connect Wallet',
                subtitle: 'Import an existing wallet using your 12-word recovery phrase.',
                useGradient: false,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ImportWalletScreen()),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool useGradient;
  final VoidCallback onTap;

  const _WalletOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.useGradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: useGradient ? kPrimaryGradient : null,
          color: useGradient ? null : kCardColor,
          borderRadius: BorderRadius.circular(20),
          border: useGradient ? null : Border.all(color: kDividerColor, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white54,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
