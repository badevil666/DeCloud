import 'package:flutter/material.dart';

class AnimatedUploadCloud extends StatefulWidget {
  final double size;

  const AnimatedUploadCloud({super.key, this.size = 100});

  @override
  State<AnimatedUploadCloud> createState() => _AnimatedUploadCloudState();
}

class _AnimatedUploadCloudState extends State<AnimatedUploadCloud>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(
      begin: -1,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 🌈 Gradient Cloud
              ShaderMask(
                shaderCallback: (Rect bounds) {
                  return const LinearGradient(
                    colors: [
                      Color(0xFF2CB1FF),
                      Color.fromRGBO(203, 45, 234, 1),
                      Color.fromARGB(255, 234, 45, 45),
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

              // ⬆️ Pulsing Upload Arrow
              Transform.scale(
                scale: _pulseAnimation.value,
                child: Icon(
                  Icons.arrow_upward,
                  size: widget.size * 0.35,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
