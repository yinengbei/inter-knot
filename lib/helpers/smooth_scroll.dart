import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';

/// A scroll physics that only allows scrollbar dragging, no wheel scrolling
class ScrollbarOnlyScrollPhysics extends ScrollPhysics {
  const ScrollbarOnlyScrollPhysics({super.parent});

  @override
  ScrollbarOnlyScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ScrollbarOnlyScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) {
    return true;
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    return offset;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    return null;
  }
}

/// Smooth wheel scroll physics with ease-in-out animation and cumulative scrolling
class SmoothWheelScrollPhysics extends ScrollPhysics {
  const SmoothWheelScrollPhysics({
    super.parent,
    this.scrollSpeed = 1.0,
  });

  final double scrollSpeed;

  @override
  SmoothWheelScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SmoothWheelScrollPhysics(
      parent: buildParent(ancestor),
      scrollSpeed: scrollSpeed,
    );
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) {
    return true;
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    return offset;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // Use friction-based simulation for smooth deceleration
    // This creates an ease-out effect
    if (velocity.abs() < 0.1) return null;
    
    return FrictionSimulation(
      0.001, // Friction coefficient (drag)
      position.pixels,
      velocity,
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
        child: builder(
          context,
          SmoothWheelScrollPhysics(scrollSpeed: scrollSpeed),
        ),
      );
    }
    return builder(context, const AlwaysScrollableScrollPhysics());
  }
}

class SmoothScroll extends StatefulWidget {
  final Widget child;
  final ScrollController controller;
  final double scrollSpeed;

  const SmoothScroll({
    super.key,
    required this.child,
    required this.controller,
    this.scrollSpeed = 1.0,
  });

  @override
  State<SmoothScroll> createState() => _SmoothScrollState();
}

class _SmoothScrollState extends State<SmoothScroll>
    with SingleTickerProviderStateMixin {
  // Track if user is dragging the scrollbar
  bool _isDraggingScrollbar = false;
  // Last position set by our scroll operation
  double _lastSetPosition = 0;
  // Timestamp of last wheel event
  DateTime? _lastWheelEventTime;
  // Accumulated scroll offset for smooth scrolling
  double _accumulatedOffset = 0.0;
  // Ticker for smooth animation
  late Ticker _ticker;
  // Current animated position
  double _animatedPosition = 0.0;
  // Target position
  double _targetPosition = 0.0;
  // Friction for smooth animation (0.1-0.3 for smooth feel)
  static const double _friction = 0.15;
  // Threshold to stop animation
  static const double _threshold = 0.1;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.controller.hasClients) {
        _lastSetPosition = widget.controller.offset;
        _animatedPosition = widget.controller.offset;
        _targetPosition = widget.controller.offset;
        _setupScrollListener();
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    widget.controller.removeListener(_onScrollPositionChanged);
    super.dispose();
  }

  void _setupScrollListener() {
    widget.controller.addListener(_onScrollPositionChanged);
  }

  void _onScrollPositionChanged() {
    if (!widget.controller.hasClients) return;

    final currentPos = widget.controller.offset;
    final now = DateTime.now();

    // If this change was caused by our animation, ignore it
    if (_lastSetPosition == currentPos) {
      return;
    }

    // The position changed externally
    // Check if it's a wheel event (within 100ms of last wheel event)
    final timeSinceWheel = _lastWheelEventTime != null
        ? now.difference(_lastWheelEventTime!)
        : null;

    if (timeSinceWheel != null && timeSinceWheel.inMilliseconds < 100) {
      // This is from wheel scrolling, update last set position
      _lastSetPosition = currentPos;
      return;
    }

    // Otherwise, assume scrollbar drag
    _isDraggingScrollbar = true;
    _animatedPosition = currentPos;
    _targetPosition = currentPos;
    _lastSetPosition = currentPos;
  }

  void _tick(Duration elapsed) {
    if (!widget.controller.hasClients) {
      _ticker.stop();
      return;
    }

    // If user is dragging scrollbar, don't animate
    if (_isDraggingScrollbar) {
      return;
    }

    // Smooth animation: move towards target
    final double diff = _targetPosition - _animatedPosition;

    // If close enough, snap and stop
    if (diff.abs() < _threshold) {
      _animatedPosition = _targetPosition;
      widget.controller.jumpTo(_animatedPosition);
      _lastSetPosition = _animatedPosition;
      _ticker.stop();
      return;
    }

    // Move towards target with friction (ease-out effect)
    _animatedPosition += diff * _friction;

    // Clamp to bounds
    final double maxPos = widget.controller.position.maxScrollExtent;
    final double minPos = widget.controller.position.minScrollExtent;
    if (_animatedPosition < minPos) _animatedPosition = minPos;
    if (_animatedPosition > maxPos) _animatedPosition = maxPos;

    widget.controller.jumpTo(_animatedPosition);
    _lastSetPosition = _animatedPosition;
  }

  void _handleScroll(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      if (event.scrollDelta.dy == 0) return;
      if (!widget.controller.hasClients) return;

      // Record wheel event timestamp
      _lastWheelEventTime = DateTime.now();
      // Not dragging scrollbar when using wheel
      _isDraggingScrollbar = false;

      // Calculate delta (cumulative scrolling)
      final double delta = event.scrollDelta.dy * widget.scrollSpeed;
      
      // Update target position (composite: 'add' - cumulative effect)
      _targetPosition += delta;

      // Clamp target to bounds
      final double maxPos = widget.controller.position.maxScrollExtent;
      final double minPos = widget.controller.position.minScrollExtent;
      if (_targetPosition < minPos) _targetPosition = minPos;
      if (_targetPosition > maxPos) _targetPosition = maxPos;

      // Start animation if not already running
      if (!_ticker.isActive) {
        _ticker.start();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _handleScroll,
      onPointerUp: (_) {
        // User released mouse button
        if (_isDraggingScrollbar) {
          _lastSetPosition = widget.controller.offset;
          _isDraggingScrollbar = false;
        }
      },
      onPointerCancel: (_) {
        // Mouse interaction cancelled
        if (_isDraggingScrollbar) {
          _isDraggingScrollbar = false;
        }
      },
      child: widget.child,
    );
  }
}
