import 'package:flutter/material.dart';
import 'package:inter_knot/components/click_region.dart';
import 'package:inter_knot/components/tab_highlight.dart';
import 'package:inter_knot/helpers/num2dur.dart';

class MyTab extends StatelessWidget {
  const MyTab({
    super.key,
    required this.text,
    required this.onTap,
    this.first = false,
    this.last = false,
    this.isSelected = false,
    this.trailing,
  }) : assert(first && !last || !first && last || !first && !last);

  final String text;
  final void Function() onTap;
  final bool first;
  final bool last;
  final bool isSelected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ClickRegion(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (isSelected)
            Positioned.fill(
              child: TabHighlight(
                isFirst: first,
                isLast: last,
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
            child: Row(
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    color: isSelected ? Colors.black : Colors.white,
                  ),
                ),
                AnimatedContainer(
                  duration: 200.ms,
                  curve: Curves.ease,
                  width: trailing == null ? 0 : 32,
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      if (trailing != null) trailing!,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
