import 'dart:math';
import 'package:flutter/material.dart';

class TwinklingStars extends StatefulWidget {
  const TwinklingStars({super.key});

  @override
  State<TwinklingStars> createState() => _TwinklingStarsState();
}

class _TwinklingStarsState extends State<TwinklingStars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final Random _rand = Random();

  late final List<_Star> _stars;

  @override
  void initState() {
    super.initState();

    _stars = List.generate(120, (_) => _Star.random(_rand));

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
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
        return CustomPaint(
          painter: _StarPainter(_stars, _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Star {
  final Offset position;
  final double radius;
  final double phase;

  _Star(this.position, this.radius, this.phase);

  factory _Star.random(Random rand) {
    return _Star(
      Offset(rand.nextDouble(), rand.nextDouble()),
      rand.nextDouble() * 1.4 + 0.3,
      rand.nextDouble() * pi * 2,
    );
  }
}

class _StarPainter extends CustomPainter {
  final List<_Star> stars;
  final double t;

  _StarPainter(this.stars, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;

    for (final star in stars) {
      final opacity = (sin(t * 2 * pi + star.phase) + 1) / 2;
      paint.color = Colors.white.withOpacity(0.2 + opacity * 0.8);

      canvas.drawCircle(
        Offset(star.position.dx * size.width, star.position.dy * size.height),
        star.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_) => true;
}
