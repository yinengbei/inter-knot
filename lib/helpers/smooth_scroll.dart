import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// A widget that provides smooth scrolling with mouse wheel and
/// a draggable scrollbar thumb.
class DraggableScrollbar extends StatefulWidget {
  final ScrollController controller;
  final Widget child;
  final double thickness;
  final double radius;
  final Color? thumbColor;
  final bool Function(ScrollNotification)? notificationPredicate;

  const DraggableScrollbar({
    super.key,
    required this.controller,
    required this.child,
    this.thickness = 8.0,
    this.radius = 4.0,
    this.thumbColor,
    this.notificationPredicate,
  });

  @override
  State<DraggableScrollbar> createState() => _DraggableScrollbarState();
}

class _DraggableScrollbarState extends State<DraggableScrollbar> {
  bool _isDragging = false;
  double _dragStartPosition = 0;
  double _dragStartThumbPosition = 0;

  Color _getThumbColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return widget.thumbColor ?? colorScheme.onSurface.withValues(alpha: 0.4);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            widget.child,
            // Custom draggable scrollbar
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: widget.thickness + 8, // Wider hit area
              child: _buildScrollbar(constraints, context),
            ),
          ],
        );
      },
    );
  }

  Widget _buildScrollbar(BoxConstraints constraints, BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        // Safe access to position: try-catch to handle multiple positions
        ScrollPosition? position;
        try {
          if (widget.controller.hasClients) {
            position = widget.controller.position;
          }
        } catch (_) {
          // Fallback if multiple clients attached
          // We can't easily determine which one to use for the scrollbar
          // so we might just use the first one or hide it.
          // But typically DraggableScrollbar wraps a single scroll view.
          // If the controller is shared, it might have multiple positions.
          // We can try to find the one that matches our context/viewport? Hard.
          // For now, let's just return empty if ambiguous to avoid crash.
          return const SizedBox.shrink();
        }

        if (position == null || !position.hasContentDimensions) {
          return const SizedBox.shrink();
        }

        final maxScroll = position.maxScrollExtent;
        final currentScroll = position.pixels;
        final viewportDimension = position.viewportDimension;

        if (maxScroll <= 0) {
          return const SizedBox.shrink();
        }

        // Calculate thumb size and position
        final scrollRatio = viewportDimension / (maxScroll + viewportDimension);
        final thumbHeight =
            (viewportDimension * scrollRatio).clamp(30.0, viewportDimension);
        final scrollProgress = currentScroll / maxScroll;
        final thumbPosition =
            scrollProgress * (viewportDimension - thumbHeight);

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragStart: (details) {
            setState(() {
              _isDragging = true;
              _dragStartPosition = details.localPosition.dy;
              _dragStartThumbPosition = thumbPosition;
            });
          },
          onVerticalDragUpdate: (details) {
            if (!_isDragging) return;

            final position = widget.controller.position;
            final maxScroll = position.maxScrollExtent;
            final viewportDimension = position.viewportDimension;
            final scrollRatio =
                viewportDimension / (maxScroll + viewportDimension);
            final thumbHeight = (viewportDimension * scrollRatio)
                .clamp(30.0, viewportDimension);

            // Calculate new position based on drag delta
            final dragDelta = details.localPosition.dy - _dragStartPosition;
            final newThumbPosition = (_dragStartThumbPosition + dragDelta)
                .clamp(0.0, viewportDimension - thumbHeight);

            // Convert thumb position to scroll position
            final scrollProgress =
                newThumbPosition / (viewportDimension - thumbHeight);
            final newScrollPosition = scrollProgress * maxScroll;

            widget.controller.jumpTo(newScrollPosition.clamp(0.0, maxScroll));
          },
          onVerticalDragEnd: (_) {
            setState(() {
              _isDragging = false;
            });
          },
          onVerticalDragCancel: () {
            setState(() {
              _isDragging = false;
            });
          },
          onTapDown: (details) {
            // Handle clicking on track to jump
            final tapY = details.localPosition.dy;
            if (tapY < thumbPosition || tapY > thumbPosition + thumbHeight) {
              // Clicked outside thumb - jump to that position
              final position = widget.controller.position;
              final maxScroll = position.maxScrollExtent;
              final viewportDimension = position.viewportDimension;

              final scrollRatio =
                  viewportDimension / (maxScroll + viewportDimension);
              final thumbHeight = (viewportDimension * scrollRatio)
                  .clamp(30.0, viewportDimension);

              final targetScrollProgress =
                  (tapY - thumbHeight / 2) / (viewportDimension - thumbHeight);
              final targetScrollPosition =
                  targetScrollProgress.clamp(0.0, 1.0) * maxScroll;

              widget.controller.animateTo(
                targetScrollPosition.clamp(0.0, maxScroll),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Center(
              child: Container(
                width: widget.thickness,
                height: viewportDimension,
                alignment: Alignment.topCenter,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: _isDragging ? widget.thickness + 2 : widget.thickness,
                  height: thumbHeight,
                  margin: EdgeInsets.only(top: thumbPosition),
                  decoration: BoxDecoration(
                    color: _getThumbColor(context),
                    borderRadius: BorderRadius.circular(widget.radius),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class AdaptiveSmoothScroll extends StatelessWidget {
  final ScrollController controller;
  final Widget Function(BuildContext context, ScrollPhysics physics) builder;
  final double scrollSpeed;

  const AdaptiveSmoothScroll({
    super.key,
    required this.controller,
    required this.builder,
    this.scrollSpeed = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 640;
    if (!isCompact) {
      return SmoothScroll(
        controller: controller,
        scrollSpeed: scrollSpeed,
        child: DraggableScrollbar(
          controller: controller,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              scrollbars: false,
            ),
            child: builder(context, const NeverScrollableScrollPhysics()),
          ),
        ),
      );
    }
    return builder(context, const AlwaysScrollableScrollPhysics());
  }
}

class SmoothScroll extends StatefulWidget {
  final Widget child;
  final ScrollController controller;
  final ScrollPhysics? physics;
  final int durationMs;
  final double scrollSpeed;

  const SmoothScroll({
    super.key,
    required this.child,
    required this.controller,
    this.physics,
    this.durationMs = 200,
    this.scrollSpeed = 1.0,
  });

  @override
  State<SmoothScroll> createState() => _SmoothScrollState();
}

class _SmoothScrollState extends State<SmoothScroll>
    with SingleTickerProviderStateMixin {
  double _targetPosition = 0;
  late Ticker _ticker;
  static const double _friction = 0.3;
  static const double _threshold = 0.5;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.controller.hasClients) {
        _targetPosition = widget.controller.offset;
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    if (!widget.controller.hasClients) {
      _ticker.stop();
      return;
    }

    final double currentPos = widget.controller.offset;
    final double diff = _targetPosition - currentPos;

    if (diff.abs() < _threshold) {
      widget.controller.jumpTo(_targetPosition);
      _ticker.stop();
      return;
    }

    final double move = diff * _friction;
    double newPos = currentPos + move;

    final double maxPos = widget.controller.position.maxScrollExtent;
    final double minPos = widget.controller.position.minScrollExtent;

    if (newPos < minPos) newPos = minPos;
    if (newPos > maxPos) newPos = maxPos;

    widget.controller.jumpTo(newPos);
  }

  void _handleScroll(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      if (event.scrollDelta.dy == 0) return;
      if (!widget.controller.hasClients) return;

      final double currentPos = widget.controller.offset;
      if (!_ticker.isActive) {
        _targetPosition = currentPos;
      }

      final double maxPos = widget.controller.position.maxScrollExtent;
      final double minPos = widget.controller.position.minScrollExtent;

      final double delta = event.scrollDelta.dy * widget.scrollSpeed;
      _targetPosition += delta;

      if (_targetPosition < minPos) _targetPosition = minPos;
      if (_targetPosition > maxPos) _targetPosition = maxPos;

      if (!_ticker.isActive) {
        _ticker.start();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _handleScroll,
      child: widget.child,
    );
  }
}
