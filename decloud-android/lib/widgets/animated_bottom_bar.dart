import 'dart:math';
import 'package:flutter/material.dart';

class AnimatedBottomBar extends StatefulWidget {
  final Widget child;

  const AnimatedBottomBar({super.key, required this.child});

  @override
  State<AnimatedBottomBar> createState() => _AnimatedBottomBarState();
}

class _AnimatedBottomBarState extends State<AnimatedBottomBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _glowStrength;
  late final Animation<Color?> _glowColor;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);

    _glowStrength = Tween<double>(
      begin: 30,
      end: 80,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _glowColor = ColorTween(
      begin: const Color(0xFFC61C46),
      end: const Color(0xFF00C2FF),
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
        final double t = _controller.value;

        final Color glow = _glowColor.value ?? const Color(0xFFC61C46);

        return Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            gradient: LinearGradient(
              begin: Alignment(cos(2 * pi * t), sin(2 * pi * t)),
              end: Alignment(-cos(2 * pi * t), -sin(2 * pi * t)),
              colors: const [
                Color(0xFFC61C46),
                Color(0xFF9F2F98),
                Color(0xFF00C2FF),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: glow.withAlpha(150),
                blurRadius: _glowStrength.value * 8,
                spreadRadius: _glowStrength.value * 0.5,
                offset: const Offset(0, -40),
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}
