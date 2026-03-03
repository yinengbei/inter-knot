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
    transitionDuration: transitionDuration ?? 200.ms,
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return Stack(
        children: [
          // Fixed Background Layer (Fade Transition)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                return Opacity(
                  opacity: const Interval(0, 0.01).transform(animation.value),
                  child: child!,
                );
              },
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
                      color:
                          Colors.black.withValues(alpha: 0.6), // Dark overlay
                      child: CustomPaint(
                        painter: PatternPainter(
                          color: Colors.white
                              .withValues(alpha: 0.15), // Subtle lines
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

Future<bool?> showDeleteConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  double width = 320,
  String confirmText = '删除',
  String cancelText = '取消',
  Color confirmTextColor = Colors.red,
}) {
  return showZZZDialog<bool>(
    context: context,
    pageBuilder: (context) {
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: width,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xff1E1E1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xff313132),
                width: 4,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(cancelText),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(
                        confirmText,
                        style: TextStyle(color: confirmTextColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
