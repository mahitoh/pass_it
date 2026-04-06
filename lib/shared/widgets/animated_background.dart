import 'dart:math';
import 'package:flutter/material.dart';

class AnimatedBackground extends StatefulWidget {
  final List<Color> colors;
  final Color? baseColor;

  const AnimatedBackground({
    super.key,
    required this.colors,
    this.baseColor,
  });

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat(reverse: true);
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
      builder: (context, child) {
        final t = _controller.value;
        final wobble = sin(t * 2 * pi);
        final wobble2 = cos(t * 2 * pi);

        return Container(
          decoration: BoxDecoration(
            color: widget.baseColor,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.colors,
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -80 + 24 * wobble,
                left: -60 + 18 * wobble2,
                child: _blob(color: widget.colors.first.withAlpha(40), size: 240),
              ),
              Positioned(
                top: 120 + 30 * wobble2,
                right: -80 + 22 * wobble,
                child: _blob(color: widget.colors.last.withAlpha(36), size: 220),
              ),
              Positioned(
                bottom: -120 + 26 * wobble,
                left: 40 + 18 * wobble2,
                child: _blob(color: widget.colors[1].withAlpha(32), size: 260),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _blob({required Color color, required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(30),
            blurRadius: 30,
            spreadRadius: 10,
          ),
        ],
      ),
    );
  }
}
