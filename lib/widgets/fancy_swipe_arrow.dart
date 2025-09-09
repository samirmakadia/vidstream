import 'package:flutter/material.dart';

class FancySwipeArrow extends StatefulWidget {
  const FancySwipeArrow({super.key, this.color = Colors.white70, this.size = 28});
  final Color color;
  final double size;

  @override
  State<FancySwipeArrow> createState() => _FancySwipeArrowState();
}

class _FancySwipeArrowState extends State<FancySwipeArrow> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        double opacity = (0.7 + (_animation.value / 24)).clamp(0.0, 1.0); // Clamp between 0-1
        return Transform.translate(
          offset: Offset(0, -_animation.value),
          child: Opacity(
            opacity: opacity,
            child: child,
          ),
        );
      },
      child: Icon(
        Icons.keyboard_arrow_down_rounded,
        size: widget.size,
        color: widget.color,
      ),
    );
  }
}
