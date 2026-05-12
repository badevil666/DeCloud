import 'dart:math';
import 'package:flutter/material.dart';

class DriftingAsteroids extends StatefulWidget {
  const DriftingAsteroids({super.key});

  @override
  State<DriftingAsteroids> createState() => _DriftingAsteroidsState();
}

class _DriftingAsteroidsState extends State<DriftingAsteroids>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final Random _rand = Random();

  late final List<_Asteroid> _asteroids;

  @override
  void initState() {
    super.initState();

    _asteroids = List.generate(6, (_) => _Asteroid.random(_rand));

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
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
          painter: _AsteroidPainter(_asteroids, _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Asteroid {
  final Offset start;
  final Offset end;
  final double radius;

  _Asteroid(this.start, this.end, this.radius);

  factory _Asteroid.random(Random rand) {
    return _Asteroid(
      Offset(rand.nextDouble(), rand.nextDouble()),
      Offset(rand.nextDouble(), rand.nextDouble()),
      rand.nextDouble() * 3 + 2,
    );
  }
}

class _AsteroidPainter extends CustomPainter {
  final List<_Asteroid> asteroids;
  final double t;

  _AsteroidPainter(this.asteroids, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    for (final a in asteroids) {
      final pos = Offset.lerp(a.start, a.end, t)!;
      canvas.drawCircle(
        Offset(pos.dx * size.width, pos.dy * size.height),
        a.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_) => true;
}
