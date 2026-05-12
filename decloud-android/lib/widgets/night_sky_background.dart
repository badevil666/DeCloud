import 'package:flutter/material.dart';
import 'twinkling_stars_painter.dart';
import 'drifting_asteroids.dart';
import 'animatedCloudLottie.dart';

class NightSkyBackground extends StatelessWidget {
  final Widget child;

  const NightSkyBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 🌌 Stars
        const Positioned.fill(child: TwinklingStars()),

        // ☄️ Asteroids
        const Positioned.fill(child: DriftingAsteroids()),

        // ☁️ Clouds (multiple layers)
        const Positioned(
          top: 80,
          left: -40,
          child: AnimatedUploadCloudLottie(size: 180),
        ),
        const Positioned(
          top: 10,
          right: -10,
          child: AnimatedUploadCloudLottie(size: 220),
        ),

        // Foreground UI
        Positioned.fill(child: child),
      ],
    );
  }
}
