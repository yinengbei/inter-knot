import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:inter_knot/components/avatar.dart';
import 'package:inter_knot/components/my_chip.dart';
import 'package:inter_knot/constants/globals.dart';
import 'package:get/get.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/components/image_viewer.dart';
import 'package:inter_knot/helpers/time_formatter.dart';
import 'package:inter_knot/models/comment.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:url_launcher/url_launcher_string.dart';

class Replies extends StatefulWidget {
  const Replies({
    super.key,
    required this.comment,
    required this.discussion,
    required this.onReply,
    this.onDelete,
    this.removingCommentIds = const <String>{},
    this.onCollapseScrollToParent,
  });

  final CommentModel comment;
  final DiscussionModel discussion;
  final void Function(String id, String? userName, {bool addPrefix}) onReply;
  final Future<void> Function(CommentModel comment)? onDelete;
  final Set<String> removingCommentIds;
  final VoidCallback? onCollapseScrollToParent;

  @override
  State<Replies> createState() => _RepliesState();
}

class _RepliesState extends State<Replies> {
  bool _expanded = false;

  Widget _buildReplyLikeButton(CommentModel reply) {
    final liked = reply.liked;
    final count = reply.likesCount;
    return GestureDetector(
      onTap: () async {
        final c = Get.find<Controller>();
        await c.toggleCommentLike(reply);
        if (mounted) setState(() {});
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            liked ? Icons.thumb_up : Icons.thumb_up_outlined,
            size: 14,
            color: liked ? const Color(0xffD7FF00) : Colors.grey,
          ),
          if (count > 0) ...[
            const SizedBox(width: 3),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 12,
                color: liked ? const Color(0xffD7FF00) : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.comment.replies.isEmpty) return const SizedBox.shrink();

    if (!_expanded) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => setState(() => _expanded = true),
          style: ButtonStyle(
            overlayColor: WidgetStateProperty.resolveWith<Color?>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.hovered)) {
                  return const Color(0xffD7FF00).withValues(alpha: 0.1);
                }
                return null;
              },
            ),
          ),
          child: Text(
            '展开 ${widget.comment.replies.length} 条回复',
            style: const TextStyle(color: Color(0xffD7FF00)),
          ),
        ),
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 600;
    final c = Get.find<Controller>();

    return Column(
      children: [
        const SizedBox(height: 10),
        for (final reply in widget.comment.replies)
          _buildReplyRemovalAnimation(
            reply,
            isMobile
                ? _buildMobileReplyItem(reply, c)
                : ListTile(
                    titleAlignment: ListTileTitleAlignment.top,
                    contentPadding: EdgeInsets.zero,
                    horizontalTitleGap: 16,
                    minVerticalPadding: 0,
                    leading: ClipOval(
                      child: InkWell(
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        borderRadius: BorderRadius.circular(50),
                        onTap: () => launchUrlString(reply.url),
                        child: Avatar(reply.author.avatar),
                      ),
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: InkWell(
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () => launchUrlString(reply.url),
                            child: Obx(() {
                              final user = c.user.value;
                              final currentAuthorId =
                                  c.authorId.value ?? user?.authorId;
                              final isMe = currentAuthorId != null &&
                                  currentAuthorId == reply.author.authorId;
                              final isOp = reply.author.login ==
                                  widget.discussion.author.login;
                              final isLayerOwner = reply.author.login ==
                                  widget.comment.author.login;

                              return Text(
                                '${isOp ? '【楼主】 ' : (isLayerOwner ? '【层主】 ' : '')}${isMe ? (user?.name ?? reply.author.name) : reply.author.name}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isMe ? const Color(0xFFFFBC2E) : null,
                                  fontWeight: isMe ? FontWeight.bold : null,
                                  fontSize: 13,
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Lv.${reply.author.level ?? 1}',
                          style: const TextStyle(
                            color: Color(0xffD7FF00),
                            fontWeight: FontWeight.bold,
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              if (reply.author.login == owner)
                                const MyChip('绳网创始人'),
                              if (collaborators.contains(reply.author.login))
                                const MyChip('绳网协作者'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        SelectionArea(
                          child: HtmlWidget(
                            reply.bodyHTML,
                            textStyle: const TextStyle(
                              fontSize: 16,
                              color:
                                  Color(0xffE0E0E0), // Light grey for replies
                            ),
                            onTapImage: (data) {
                              if (data.sources.isEmpty) return;
                              final url = data.sources.first.url;
                              ImageViewer.show(context,
                                  imageUrls: [url], heroTagPrefix: null);
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              formatRelativeTime(
                                reply.createdAt,
                                fallbackPattern: 'yyyy-MM-dd HH:mm',
                              ),
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.grey),
                            ),
                            const SizedBox(width: 8),
                            _buildReplyLikeButton(reply),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => widget.onReply(
                                  widget.comment.id, reply.author.name,
                                  addPrefix: true),
                              style: ButtonStyle(
                                padding:
                                    WidgetStateProperty.all(EdgeInsets.zero),
                                minimumSize: WidgetStateProperty.all(Size.zero),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                overlayColor:
                                    WidgetStateProperty.resolveWith<Color?>(
                                  (Set<WidgetState> states) {
                                    if (states.contains(WidgetState.hovered)) {
                                      return const Color(0xffD7FF00)
                                          .withValues(alpha: 0.1);
                                    }
                                    return null;
                                  },
                                ),
                                foregroundColor:
                                    WidgetStateProperty.resolveWith<Color>(
                                  (Set<WidgetState> states) {
                                    if (states.contains(WidgetState.hovered)) {
                                      return const Color(0xffD7FF00);
                                    }
                                    return Colors.grey;
                                  },
                                ),
                              ),
                              child: const Text('回复',
                                  style: TextStyle(fontSize: 12)),
                            ),
                            if (widget.onDelete != null) ...[
                              const SizedBox(width: 8),
                              Obx(() {
                                final user = c.user.value;
                                final currentAuthorId =
                                    c.authorId.value ?? user?.authorId;
                                final isMe = currentAuthorId != null &&
                                    currentAuthorId == reply.author.authorId;
                                if (!isMe) return const SizedBox.shrink();

                                final deleting = widget.removingCommentIds
                                    .contains(reply.id);

                                return TextButton(
                                  onPressed: deleting
                                      ? null
                                      : () => widget.onDelete?.call(reply),
                                  style: ButtonStyle(
                                    padding: WidgetStateProperty.all(
                                        EdgeInsets.zero),
                                    minimumSize:
                                        WidgetStateProperty.all(Size.zero),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                    overlayColor:
                                        WidgetStateProperty.resolveWith<Color?>(
                                      (Set<WidgetState> states) {
                                        if (states
                                            .contains(WidgetState.hovered)) {
                                          return Colors.red
                                              .withValues(alpha: 0.12);
                                        }
                                        return null;
                                      },
                                    ),
                                    foregroundColor: WidgetStateProperty.all(
                                        Colors.redAccent),
                                  ),
                                  child: Text(
                                    deleting ? '删除中...' : '删除',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                        const Divider(),
                      ],
                    ),
                  ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () {
              setState(() => _expanded = false);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                widget.onCollapseScrollToParent?.call();
              });
            },
            style: ButtonStyle(
              overlayColor: WidgetStateProperty.resolveWith<Color?>(
                (Set<WidgetState> states) {
                  if (states.contains(WidgetState.hovered)) {
                    return const Color(0xffD7FF00).withValues(alpha: 0.1);
                  }
                  return null;
                },
              ),
            ),
            child: const Text(
              '收起回复',
              style: TextStyle(color: Color(0xffD7FF00)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReplyRemovalAnimation(CommentModel reply, Widget child) {
    final removing = widget.removingCommentIds.contains(reply.id);
    return AnimatedOpacity(
      opacity: removing ? 0 : 1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: ClipRect(
          child: Align(
            heightFactor: removing ? 0 : 1,
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildMobileReplyItem(dynamic reply, Controller c) {
    final baseTitleStyle =
        Theme.of(context).textTheme.titleMedium ?? const TextStyle();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipOval(
                child: InkWell(
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  borderRadius: BorderRadius.circular(50),
                  onTap: () => launchUrlString(reply.url),
                  child: Avatar(reply.author.avatar, size: 32),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: InkWell(
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  onTap: () => launchUrlString(reply.url),
                  child: Obx(() {
                    final user = c.user.value;
                    final currentAuthorId = c.authorId.value ?? user?.authorId;
                    final isMe = currentAuthorId != null &&
                        currentAuthorId == reply.author.authorId;
                    final isOp =
                        reply.author.login == widget.discussion.author.login;
                    final isLayerOwner =
                        reply.author.login == widget.comment.author.login;

                    return Text(
                      '${isOp ? '【楼主】 ' : (isLayerOwner ? '【层主】 ' : '')}${isMe ? (user?.name ?? reply.author.name) : reply.author.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: baseTitleStyle.copyWith(
                        color: isMe
                            ? const Color(0xFFFFBC2E)
                            : baseTitleStyle.color,
                        fontWeight:
                            isMe ? FontWeight.bold : baseTitleStyle.fontWeight,
                        fontSize: 13,
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Lv.${reply.author.level ?? 1}',
                style: const TextStyle(
                  color: Color(0xffD7FF00),
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 0, top: 8),
            child: SelectionArea(
              child: HtmlWidget(
                reply.bodyHTML,
                textStyle: const TextStyle(
                  fontSize: 16,
                  color: Color(0xffE0E0E0),
                ),
                onTapImage: (data) {
                  if (data.sources.isEmpty) return;
                  final url = data.sources.first.url;
                  ImageViewer.show(context,
                      imageUrls: [url], heroTagPrefix: null);
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      formatRelativeTime(
                        reply.createdAt,
                        fallbackPattern: 'yyyy-MM-dd HH:mm',
                      ),
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    TextButton(
                      onPressed: () => widget.onReply(
                        widget.comment.id,
                        reply.author.name,
                        addPrefix: true,
                      ),
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(EdgeInsets.zero),
                        minimumSize: WidgetStateProperty.all(Size.zero),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        foregroundColor: WidgetStateProperty.all(Colors.grey),
                        overlayColor: WidgetStateProperty.resolveWith<Color?>(
                          (Set<WidgetState> states) {
                            if (states.contains(WidgetState.hovered)) {
                              return const Color(0xffD7FF00).withValues(
                                alpha: 0.1,
                              );
                            }
                            return null;
                          },
                        ),
                      ),
                      child: const Text('回复', style: TextStyle(fontSize: 12)),
                    ),
                    if (widget.onDelete != null)
                      Obx(() {
                        final user = c.user.value;
                        final currentAuthorId =
                            c.authorId.value ?? user?.authorId;
                        final isMe = currentAuthorId != null &&
                            currentAuthorId == reply.author.authorId;
                        if (!isMe) return const SizedBox.shrink();

                        final deleting =
                            widget.removingCommentIds.contains(reply.id);

                        return TextButton(
                          onPressed: deleting
                              ? null
                              : () => widget.onDelete?.call(reply),
                          style: ButtonStyle(
                            padding: WidgetStateProperty.all(EdgeInsets.zero),
                            minimumSize: WidgetStateProperty.all(Size.zero),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            foregroundColor:
                                WidgetStateProperty.all(Colors.redAccent),
                            overlayColor:
                                WidgetStateProperty.resolveWith<Color?>(
                              (Set<WidgetState> states) {
                                if (states.contains(WidgetState.hovered)) {
                                  return Colors.red.withValues(alpha: 0.12);
                                }
                                return null;
                              },
                            ),
                          ),
                          child: Text(
                            deleting ? '删除中...' : '删除',
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      }),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildReplyLikeButton(reply),
            ],
          ),
          const Divider(),
        ],
      ),
    );
  }
}
