import 'package:flutter/material.dart';

// Redefining for simpler "Pulse" logic without complex intervals
class ThreePulsingDots extends StatefulWidget {
  final Color color;
  final double size;

  const ThreePulsingDots({
    super.key,
    this.color = Colors.white,
    this.size = 24.0,
  });

  @override
  State<ThreePulsingDots> createState() => _ThreePulsingDotsState();
}

class _ThreePulsingDotsState extends State<ThreePulsingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size * 2,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _PulsingDot(
              animation: _controller,
              delay: 0.0,
              color: widget.color,
              size: widget.size / 3,
            ),
            _PulsingDot(
              animation: _controller,
              delay: 0.2,
              color: widget.color,
              size: widget.size / 3,
            ),
            _PulsingDot(
              animation: _controller,
              delay: 0.4,
              color: widget.color,
              size: widget.size / 3,
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatelessWidget {
  final AnimationController animation;
  final double delay; // 0.0 to 1.0
  final Color color;
  final double size;

  const _PulsingDot({
    required this.animation,
    required this.delay,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _DelayedCurve(parent: animation, delay: delay),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

// Custom curve that loops effectively
class _DelayedCurve extends Animation<double> {
  final Animation<double> parent;
  final double delay;

  _DelayedCurve({required this.parent, required this.delay});

  @override
  void addListener(VoidCallback listener) => parent.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => parent.removeListener(listener);

  @override
  void addStatusListener(AnimationStatusListener listener) =>
      parent.addStatusListener(listener);

  @override
  void removeStatusListener(AnimationStatusListener listener) =>
      parent.removeStatusListener(listener);

  @override
  AnimationStatus get status => parent.status;

  @override
  double get value {
    // Offset the parent value (0..1) by delay
    final double val = (parent.value + delay) % 1.0;
    // Map 0..1 to a triangle/sine wave 0->1->0
    if (val < 0.5) {
      return 0.3 + (0.7 * (val * 2)); // 0.3 -> 1.0
    } else {
      return 1.0 - (0.7 * ((val - 0.5) * 2)); // 1.0 -> 0.3
    }
  }
}
