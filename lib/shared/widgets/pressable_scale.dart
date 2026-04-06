import 'package:flutter/material.dart';

class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final pressed = _scale < 1.0;
    return AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: pressed ? 0.96 : 1.0,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
            onTap: widget.onTap,
            onHighlightChanged: (isPressed) {
              setState(() {
                _scale = isPressed ? 0.97 : 1.0;
              });
            },
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
