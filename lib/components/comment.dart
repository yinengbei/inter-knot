import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:inter_knot/components/avatar.dart';
import 'package:inter_knot/components/my_chip.dart';
import 'package:inter_knot/components/replies.dart';
import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/helpers/flatten.dart';
import 'package:inter_knot/models/comment.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';

class Comment extends StatefulWidget {
  const Comment({super.key, required this.discussion, this.loading = false});

  final DiscussionModel discussion;
  final bool loading;

  @override
  State<Comment> createState() => _CommentState();
}

class _CommentState extends State<Comment> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(Comment oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  Widget _buildFooter() {
    if (widget.discussion.comments.isNotEmpty &&
        widget.discussion.comments.last.hasNextPage) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: Text('没有更多评论了')),
    );
  }

  Widget _buildCommentItem(CommentModel comment, int index, bool isMobile) {
    Widget content = ListTile(
      titleAlignment: ListTileTitleAlignment.top,
      contentPadding: EdgeInsets.zero,
      horizontalTitleGap: 8,
      minVerticalPadding: 0,
      leading: ClipOval(
        child: InkWell(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          borderRadius: BorderRadius.circular(50),
          onTap: () => launchUrlString(comment.url),
          child: Avatar(comment.author.avatar),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: InkWell(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onTap: () => launchUrlString(comment.url),
              child: Text(
                comment.author.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (comment.author.login == widget.discussion.author.login)
                  const MyChip('楼主'),
                if (comment.author.login == owner) const MyChip('绳网创始人'),
                if (collaborators.contains(comment.author.login))
                  const MyChip('绳网协作者'),
              ],
            ),
          ),
        ],
      ),
      trailing: MyChip('F${index + 1}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('yyyy-MM-dd HH:mm').format(comment.createdAt.toLocal()),
          ),
          const SizedBox(height: 8),
          SelectionArea(
            child: HtmlWidget(
              comment.bodyHTML,
              textStyle: const TextStyle(
                fontSize: 16,
                // Removed explicit color to allow animation
              ),
            ),
          ),
          Replies(comment: comment, discussion: widget.discussion),
        ],
      ),
    );

    content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        content,
        const Divider(thickness: 2, height: 32),
      ],
    );

    if (isMobile) {
      // Mobile: Return static content without ScrollItemEffect
      // Also restore default text color since it's not handled by animation
      return DefaultTextStyle.merge(
        style: const TextStyle(color: Color(0xff808080)),
        child: content,
      );
    }

    return _ScrollItemEffect(child: content);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 600;

    final list = Column(
      children: [
        ...widget.discussion.comments
            .map((e) => e.nodes)
            .flat
            .toList()
            .asMap()
            .entries
            .map(
                (entry) => _buildCommentItem(entry.value, entry.key, isMobile)),
        _buildFooter(),
      ],
    );

    if (isMobile) {
      return list;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.9 + 0.1 * value,
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: list,
    );
  }
}

class _ScrollItemEffect extends StatefulWidget {
  final Widget child;

  const _ScrollItemEffect({required this.child});

  @override
  State<_ScrollItemEffect> createState() => _ScrollItemEffectState();
}

class _ScrollItemEffectState extends State<_ScrollItemEffect> {
  ScrollPosition? _position;
  // Use a single notifier for the focus factor (0.0 to 1.0)
  // 1.0 means perfectly focused, 0.0 means completely out of focus (far top/bottom)
  final ValueNotifier<double> _focusFactor = ValueNotifier(1.0);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _position?.removeListener(_update);
    _position = Scrollable.of(context).position;
    _position?.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void dispose() {
    _position?.removeListener(_update);
    _focusFactor.dispose();
    super.dispose();
  }

  void _update() {
    if (!mounted || _position == null) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.attached) return;

    final scrollBox = _position!.context.notificationContext?.findRenderObject()
        as RenderBox?;
    if (scrollBox == null || !scrollBox.attached) return;

    try {
      final offset = renderBox.localToGlobal(Offset.zero, ancestor: scrollBox);
      final y = offset.dy;
      final viewHeight = scrollBox.size.height;
      final itemHeight = renderBox.size.height;
      final itemCenterY = y + itemHeight / 2;

      // Define focus band center
      // Shifted down to 0.5 (center) from 0.35 to allow stronger fade at top
      // and delayed focus at bottom
      final focusY = viewHeight * 0.5;

      // Calculate normalized distance from focus center
      // Radius reduced slightly to 0.45 * viewHeight to make edges fade faster
      final distance = (itemCenterY - focusY).abs();
      final normalized = (distance / (viewHeight * 0.45)).clamp(0.0, 1.0);

      // Non-linear easing: 1.0 (focus) -> 0.0 (edge)
      final eased = Curves.easeOutCubic.transform(1 - normalized);

      if ((_focusFactor.value - eased).abs() > 0.001) {
        _focusFactor.value = eased;
      }
    } catch (e) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _focusFactor,
      builder: (context, factor, child) {
        // Non-linear interpolation for properties
        final easeCurve = Curves.easeOutQuart.transform(factor);

        final scale = 0.85 + 0.15 * easeCurve;
        final opacity = 0.4 + 0.6 * easeCurve;
        final color = Color.lerp(
          Colors.grey.shade500,
          Colors.black87,
          easeCurve,
        )!;
        final yOffset = (1 - easeCurve) * 12;

        return Transform.translate(
          offset: Offset(0, yOffset),
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: DefaultTextStyle.merge(
                style: TextStyle(color: color),
                child: child!,
              ),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
