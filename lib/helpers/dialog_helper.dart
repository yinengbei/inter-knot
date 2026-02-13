import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:inter_knot/components/pattern_painter.dart';
import 'package:inter_knot/helpers/num2dur.dart';

/// 显示 ZZZ 风格的通用弹窗
Future<T?> showZZZDialog<T>({
  required BuildContext context,
  required WidgetBuilder pageBuilder,
  bool barrierDismissible = true,
  String barrierLabel = '取消',
  Duration? transitionDuration,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel,
    pageBuilder: (context, animation, secondaryAnimation) {
      return pageBuilder(context);
    },
    transitionDuration: transitionDuration ?? 300.ms,
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return Stack(
        children: [
          // Fixed Background Layer (Fade Transition)
          Positioned.fill(
            child: FadeTransition(
              opacity: animation,
              child: IgnorePointer(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Blur Effect
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: const SizedBox.expand(),
                    ),
                    // Texture + Overlay
                    Container(
                      color: Colors.black.withValues(alpha: 0.6), // Dark overlay
                      child: CustomPaint(
                        painter: PatternPainter(
                          color: Colors.white.withValues(alpha: 0.1), // Subtle lines
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Dialog Content (Slide/Fade Transition)
          AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final curve = Curves.easeOutQuart;
              final double value = animation.value;
              final double curvedValue = curve.transform(value);

              Offset translation;
              if (animation.status == AnimationStatus.reverse) {
                translation = Offset(-0.05 * (1 - curvedValue), 0.0);
              } else {
                translation = Offset(0.05 * (1 - curvedValue), 0.0);
              }

              return Opacity(
                opacity: curvedValue,
                child: FractionalTranslation(
                  translation: translation,
                  child: child,
                ),
              );
            },
            child: RepaintBoundary(child: child),
          ),
        ],
      );
    },
  );
}
