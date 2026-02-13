import 'package:flutter/material.dart';

class PatternPainter extends CustomPainter {
  final Color color;

  PatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Pattern size: 5px x 5px
    const double patternSize = 5.0;

    // Start from -size.height to ensure coverage on the left side
    for (double i = -size.height; i < size.width; i += patternSize) {
      canvas.drawLine(
          Offset(i, 0), Offset(i + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
