import 'dart:math';
import 'package:flutter/material.dart';

class TabHighlight extends StatefulWidget {
  const TabHighlight({
    super.key,
    this.isFirst = false,
    this.isLast = false,
  });

  final bool isFirst;
  final bool isLast;

  @override
  State<TabHighlight> createState() => _TabHighlightState();
}

class _TabHighlightState extends State<TabHighlight>
    with TickerProviderStateMixin {
  late final AnimationController _colorController;
  late final AnimationController _scaleController;
  late final Animation<Color?> _colorAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Color Animation: 1s linear infinite alternate
    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _colorAnimation = ColorTween(
      begin: const Color(0xfffbfe00),
      end: const Color(0xffdcfe00),
    ).animate(CurvedAnimation(
      parent: _colorController,
      curve: Curves.linear,
    ));

    // Scale Animation: 0.6s total duration.
    // "Expand to max (1.3) then IMMEDIATELY fast shrink"
    // We can use a TweenSequence to define the phases explicitly.
    // Phase 1: Expand 1.0 -> 1.3 (e.g., 40% of time, smooth/easeOut)
    // Phase 2: Shrink 1.3 -> 1.0 (e.g., 60% of time, fast/easeIn)
    // Wait, "fast shrink" usually means shorter duration.
    // Let's try:
    // Expand: 50% time, curve: easeOut (Decelerate)
    // Shrink: 50% time, curve: easeIn (Accelerate) -> No, user said "fast shrink".
    // Maybe: Expand 60% time (slower), Shrink 40% time (faster)?
    // Or maybe just a single curve that peaks early?
    // Let's use TweenSequence for ultimate control.

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(
          milliseconds: 600), // Slightly longer to feel the rhythm
    )..repeat(); // Loop continuously

    _scaleAnimation = TweenSequence<double>([
      // Phase 1: Expand (1.0 -> 1.3)
      // "slow start then fast" -> Accelerate -> easeIn curves.
      // Curves.easeInQuad or easeInCubic.
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.1, end: 1.25)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 50.0, // 50% of duration
      ),
      // Phase 2: Shrink (1.3 -> 1.0)
      // "fast shrink" -> Accelerate or keep fast start?
      // Usually "fast shrink" implies it happens quickly.
      // If we use fastOutSlowIn, it starts fast and slows down.
      // If we use linear, it's constant.
      // Let's stick with fastOutSlowIn for shrink as it feels "snappy".
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.25, end: 1.1)
            .chain(CurveTween(curve: Curves.fastOutSlowIn)),
        weight: 50.0, // 50% of duration
      ),
    ]).animate(_scaleController);
  }

  @override
  void dispose() {
    _colorController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_colorController, _scaleController]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: CustomPaint(
            painter: _TabHighlightPainter(
              color: _colorAnimation.value ?? const Color(0xfffbfe00),
              isFirst: widget.isFirst,
              isLast: widget.isLast,
            ),
          ),
        );
      },
    );
  }
}

class _TabHighlightPainter extends CustomPainter {
  final Color color;
  final bool isFirst;
  final bool isLast;

  _TabHighlightPainter({
    required this.color,
    required this.isFirst,
    required this.isLast,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final w = size.width;
    final h = size.height;

    // skew offset: tan(27 degrees) * (h / 2) ?
    // The vue implementation uses skewX(-27deg).
    // tan(27 deg) approx 0.51.
    // Let's use a fixed relative offset or calculate based on height.
    // If we want the slant to be exactly 27 degrees from vertical:
    // slant_width = h * tan(27 * pi / 180).
    final double slantWidth = h * tan(27 * pi / 180);

    // We want the visual center of the slanted edge to be at the boundary.
    // So top is +slantWidth/2, bottom is -slantWidth/2 relative to the vertical line.

    // Unified Shape: Left Rounded, Right Skewed with Rounded Corners
    final r = h / 2; // Radius for rounded corner (semicircle) - Left side
    const double crTop = 10.0; // Corner radius for top-right side
    const double crBottom = 16.0; // Larger corner radius for bottom-right side

    if (isLast) {
      // "My" Tab: Left Skewed, Right Rounded

      // Vertices of the skewed left side (before rounding)
      // Top Left is slantWidth/2 (Right/Inside). Bottom Left is -slantWidth/2 (Left/Outside).
      // This creates a '/' slant, parallel to the first tab's right edge.
      final double topLeftX = slantWidth / 2;
      final double bottomLeftX = -slantWidth / 2;

      // Angles for tangent calculations
      // Top Left Angle is Obtuse (117 deg). Bottom Left Angle is Acute (63 deg).
      final double angleTL = (90 + 27) * pi / 180;
      final double angleBL = (90 - 27) * pi / 180;

      // Tangent Distances
      // Use crTop for Top Corner, but reduce crBottom for Bottom Corner to make it sharper (less rounded) as requested.
      // "don't make it so rounded" -> smaller radius.
      final double customCrBottom = 8.0;

      final double tanDistTL = crTop / tan(angleTL / 2);
      final double tanDistBL = customCrBottom / tan(angleBL / 2);

      // Normalized vector for the slanted line (from bottom-left to top-left)
      // dx = slantWidth, dy = -h
      final double dx = slantWidth;
      final double dy = -h;
      final double len = sqrt(dx * dx + dy * dy);
      final double ndx = dx / len;
      final double ndy = dy / len;

      path.moveTo(w - r, 0); // Start at top-right (before arc)

      // 1. Right Arc
      path.arcToPoint(Offset(w - r, h),
          radius: Radius.circular(r), clockwise: true);

      // 2. Bottom Line -> Bottom-Left Corner
      // Line goes to (bottomLeftX + tanDistBL, h)
      path.lineTo(bottomLeftX + tanDistBL, h);

      // 3. Arc at Bottom Left
      // End point on slanted line: Vertex + (ndx, ndy) * tanDistBL
      // Vertex is (bottomLeftX, h)
      path.arcToPoint(
        Offset(bottomLeftX + ndx * tanDistBL, h + ndy * tanDistBL),
        radius: Radius.circular(customCrBottom),
        clockwise: true,
      );

      // 4. Slanted Line -> Top-Left Corner
      // Line to: Vertex - (ndx, ndy) * tanDistTL
      // Vertex is (topLeftX, 0)
      path.lineTo(topLeftX - ndx * tanDistTL, 0 - ndy * tanDistTL);

      // 5. Arc at Top Left
      // End point on top line: Vertex + (tanDistTL, 0)
      path.arcToPoint(
        Offset(topLeftX + tanDistTL, 0),
        radius: const Radius.circular(crTop),
        clockwise: true, // Up-Right -> Right. Clockwise.
      );

      // 6. Close
      path.close();
    } else {
      // "Push" Tab: Left Rounded, Right Skewed (Original Logic)

      // Vertices of the skewed right side (before rounding)
      final double topRightX = w + slantWidth / 2;
      final double bottomRightX = w - slantWidth / 2;

      // Angles for tangent calculations
      // Top Right Angle is acute: 90 - 27 = 63 degrees
      final double angleTR = (90 - 27) * pi / 180;
      // Bottom Right Angle is obtuse: 90 + 27 = 117 degrees
      final double angleBR = (90 + 27) * pi / 180;

      // Distance from vertex to tangent point = R / tan(theta/2)
      final double tanDistTR = crTop / tan(angleTR / 2);
      final double tanDistBR = crBottom / tan(angleBR / 2);

      // Normalized vector for the slanted line (from top-right to bottom-right)
      final double dx = -slantWidth;
      final double dy = h;
      final double len = sqrt(dx * dx + dy * dy);
      final double ndx = dx / len;
      final double ndy = dy / len;

      path.moveTo(r, 0);

      // 1. Top Line -> Top-Right Corner
      // Stop short of the vertex
      path.lineTo(topRightX - tanDistTR, 0);
      // Draw arc to the point on the slanted line
      // Point on slant line = Vertex + (ndx, ndy) * tanDistTR
      path.arcToPoint(
        Offset(topRightX + ndx * tanDistTR, 0 + ndy * tanDistTR),
        radius: const Radius.circular(crTop),
        clockwise: true,
      );

      // 2. Slanted Line -> Bottom-Right Corner
      // Stop short of the bottom vertex
      // Vertex is (bottomRightX, h)
      // Point on slant line = Vertex - (ndx, ndy) * tanDistBR
      path.lineTo(bottomRightX - ndx * tanDistBR, h - ndy * tanDistBR);
      // Draw arc to the point on the bottom line
      // Point on bottom line = Vertex - (tanDistBR, 0) (moving left)
      path.arcToPoint(
        Offset(bottomRightX - tanDistBR, h),
        radius: const Radius.circular(crBottom),
        clockwise: true,
      );

      // 3. Bottom Line -> Left Rounded Start
      path.lineTo(r, h);

      // 4. Left Arc
      path.arcToPoint(Offset(r, 0),
          radius: Radius.circular(r), clockwise: true);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TabHighlightPainter oldDelegate) {
    return color != oldDelegate.color ||
        isFirst != oldDelegate.isFirst ||
        isLast != oldDelegate.isLast;
  }
}
