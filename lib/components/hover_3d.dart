import 'package:flutter/material.dart';

class Hover3D extends StatefulWidget {
  const Hover3D({
    super.key,
    required this.child,
    this.scale = 1.05,
    this.tiltX = 0.1,
    this.tiltY = 0.1,
    this.duration = const Duration(milliseconds: 200),
  });

  final Widget child;
  final double scale;
  final double tiltX;
  final double tiltY;
  final Duration duration;

  @override
  State<Hover3D> createState() => _Hover3DState();
}

class _Hover3DState extends State<Hover3D> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  final ValueNotifier<Offset> _mousePos = ValueNotifier(Offset.zero);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _mousePos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _controller.forward(),
      onExit: (_) {
        _controller.reverse();
      },
      onHover: (event) {
        final renderBox = context.findRenderObject();
        if (renderBox is! RenderBox) return;
        final size = renderBox.size;
        final center = size.center(Offset.zero);
        final localPos = event.localPosition;
        final offset = localPos - center;

        // Normalize offset (-1.0 to 1.0)
        final x = offset.dx / (size.width / 2);
        final y = offset.dy / (size.height / 2);

        _mousePos.value = Offset(x, y);
      },
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge([_controller, _mousePos]),
          builder: (context, child) {
            final scale = _scaleAnimation.value;
            final pos = _mousePos.value;

            // Calculate tilt
            // To make the mouse position "lower" (pushed down), we need to rotate:
            // Mouse Right (positive x) -> Rotate Y axis negative (push right side down)
            // Mouse Down (positive y) -> Rotate X axis positive (push bottom side down)
            final rotateY = -pos.dx * widget.tiltY * _controller.value;
            final rotateX = pos.dy * widget.tiltX * _controller.value;

            final transform = Matrix4.identity()
              ..setEntry(3, 2, 0.001) // Perspective
              ..rotateX(rotateX)
              ..rotateY(rotateY)
              ..scaleByDouble(scale, scale, scale, 1.0);

            return Transform(
              transform: transform,
              alignment: Alignment.center,
              child: widget.child,
            );
          },
        ),
      ),
    );
  }
}
