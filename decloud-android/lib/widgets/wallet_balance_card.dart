import 'package:flutter/material.dart';
import '../../../core/constants.dart';

class WalletBalanceCard extends StatelessWidget {
  final String address;
  final double balance;
  final double maxBalance;
  final Animation<double> animation;
  final VoidCallback onSend;

  const WalletBalanceCard({
    super.key,
    required this.address,
    required this.balance,
    required this.maxBalance,
    required this.animation,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final scale = Curves.easeOutBack.transform(animation.value.clamp(0.0, 1.0));

    return Transform.scale(
      scale: scale,
      alignment: Alignment.topCenter,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: kPrimaryGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(50),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Wallet Address",
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              address,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              "Wallet Balance",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              "$balance DCLD",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 16),

            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: (balance / maxBalance).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),

            const SizedBox(height: 20),

            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: onSend,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  elevation: 0,
                  shape: const StadiumBorder(),
                ),
                child: const Text(
                  "Send Tokens",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
