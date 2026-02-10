import 'package:flutter/material.dart';

class FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const FadeIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: widget.children.asMap().entries.map((entry) {
        final i = entry.key;
        final child = entry.value;
        final isActive = i == widget.index;

        return AnimatedOpacity(
          opacity: isActive ? 1.0 : 0.0,
          duration: widget.duration,
          curve: Curves.ease,
          child: IgnorePointer(
            ignoring: !isActive,
            child: child,
          ),
        );
      }).toList(),
    );
  }
}
