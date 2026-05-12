import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedUploadCloudLottie extends StatefulWidget {
  final double size;

  const AnimatedUploadCloudLottie({super.key, this.size = 120});

  @override
  State<AnimatedUploadCloudLottie> createState() =>
      _AnimatedUploadCloudLottieState();
}

class _AnimatedUploadCloudLottieState extends State<AnimatedUploadCloudLottie>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final t = _controller.value;

        // Floating motion (sine wave)
        final floatY = math.sin(t * math.pi) * 60;

        // Arrow animation: slides up and fades in/out repeatedly
        final arrowT = (t * 10) % 1.0; // Loops 10 times during the 20s cycle
        final arrowOffset = (1 - arrowT) * 15 - 5; // Slides from +10 to -5
        final arrowOpacity = math.sin(arrowT * math.pi).clamp(0.0, 1.0);

        return Transform.translate(
          offset: Offset(0, floatY),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 🌈 Gradient Cloud (Lottie-style shimmer)
              ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    colors: const [
                      Color(0xFFBB2BC5),
                      Color(0xFF5B2BEF),
                      Color(0xFF2CB1FF),
                    ],
                    stops: [
                      (t - 0.2).clamp(0.0, 1.0),
                      t,
                      (t + 0.2).clamp(0.0, 1.0),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds);
                },
                child: Icon(
                  Icons.cloud_upload_outlined,
                  size: widget.size,
                  color: Colors.white,
                ),
              ),

              // ⬆️ Upload Arrow (slide + fade like Lottie)
              Transform.translate(
                offset: Offset(0, arrowOffset),
                child: Opacity(
                  opacity: arrowOpacity,
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    size: widget.size * 0.35,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
