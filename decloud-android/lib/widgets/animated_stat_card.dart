import 'package:flutter/material.dart';
import '../core/constants.dart';

class AnimatedStatCard extends StatelessWidget {
  final AnimationController controller;
  final String title;
  final String valueText;
  final double progress; // 0.0 → 1.0
  final VoidCallback? onAction;
  final String actionText;

  const AnimatedStatCard({
    super.key,
    required this.controller,
    required this.title,
    required this.valueText,
    required this.progress,
    this.onAction,
    required this.actionText,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final scale = Curves.easeOutBack.transform(
          controller.value.clamp(0.0, 1.0),
        );

        return Transform.scale(scale: scale, child: child);
      },
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
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              valueText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 16),

            AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: (progress * controller.value).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  elevation: 0,
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  actionText,
                  style: const TextStyle(
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
