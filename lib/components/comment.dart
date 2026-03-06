import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/components/avatar.dart';
import 'package:inter_knot/components/image_viewer.dart';
import 'package:inter_knot/components/my_chip.dart';
import 'package:inter_knot/components/replies.dart';
import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/dialog_helper.dart';
import 'package:inter_knot/helpers/flatten.dart';
import 'package:inter_knot/helpers/time_formatter.dart';
import 'package:inter_knot/helpers/toast.dart';
import 'package:inter_knot/models/comment.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:url_launcher/url_launcher_string.dart';

class Comment extends StatefulWidget {
  const Comment({
    super.key,
    required this.discussion,
    this.loading = false,
    this.onReply,
    this.useListView = false,
    this.controller,
    this.physics,
    this.padding,
  });

  final DiscussionModel discussion;
  final bool loading;
  final void Function(String parentId, String? userName, {bool addPrefix})?
      onReply;

  final bool useListView;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;

  @override
  State<Comment> createState() => _CommentState();
}

class _CommentState extends State<Comment> {
  final _deletingCommentIds = <String>{};
  final _removingCommentIds = <String>{};

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(Comment oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  bool _removeFromReplies(Set<CommentModel> replies, String id) {
    for (final reply in replies.toList()) {
      if (reply.id == id) {
        replies.remove(reply);
        return true;
      }
      if (_removeFromReplies(reply.replies, id)) return true;
    }
    return false;
  }

  bool _removeCommentById(String id) {
    for (final page in widget.discussion.comments) {
      for (final comment in page.nodes.toList()) {
        if (comment.id == id) {
          page.nodes.remove(comment);
          return true;
        }
        if (_removeFromReplies(comment.replies, id)) return true;
      }
    }
    return false;
  }

  Future<void> _deleteComment(CommentModel comment) async {
    if (comment.id.isEmpty) {
      showToast('评论ID无效', isError: true);
      return;
    }
    if (!await c.ensureLogin()) return;

    final user = c.user.value;
    final currentAuthorId = c.authorId.value ?? user?.authorId;
    final isMe =
        currentAuthorId != null && currentAuthorId == comment.author.authorId;
    if (!isMe) {
      showToast('只能删除自己的评论', isError: true);
      return;
    }

    final confirmed = await showDeleteConfirmDialog(
      context: context,
      title: '确认删除评论',
      message: '删除后不可恢复，确定继续吗？',
    );

    if (confirmed != true) return;

    setState(() => _deletingCommentIds.add(comment.id));
    try {
      final res = await Get.find<Api>().deleteComment(comment.id);
      if (res.hasError) {
        throw Exception(res.statusText ?? '删除失败');
      }

      if (mounted) {
        setState(() => _removingCommentIds.add(comment.id));
      }
      await Future.delayed(const Duration(milliseconds: 220));

      if (_removeCommentById(comment.id)) {
        if (widget.discussion.commentsCount > 0) {
          widget.discussion.commentsCount--;
        }
      }

      if (mounted) setState(() {});
      showToast('评论已删除');
    } catch (e) {
      showToast('删除评论失败: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _deletingCommentIds.remove(comment.id);
          _removingCommentIds.remove(comment.id);
        });
      }
    }
  }

  Widget _buildCommentRemovalAnimation(CommentModel comment, Widget child) {
    final removing = _removingCommentIds.contains(comment.id);
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

  Widget _buildCommentLikeButton(CommentModel comment) {
    final liked = comment.liked;
    final count = comment.likesCount;
    return GestureDetector(
      onTap: () async {
        await c.toggleCommentLike(comment);
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

  Widget _buildFooter() {
    if (widget.discussion.comments.isNotEmpty &&
        widget.discussion.comments.last.hasNextPage) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Image.asset(
            'assets/images/Bangboo.gif',
            width: 80,
            height: 80,
          ),
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: Text('没有更多评论了')),
    );
  }

  Widget _buildCommentItem(CommentModel comment, int index, bool isMobile) {
    if (isMobile) {
      return _buildCommentRemovalAnimation(
        comment,
        _buildMobileCommentItem(comment, index),
      );
    }

    return Builder(
      builder: (itemContext) {
        Widget content = ListTile(
          titleAlignment: ListTileTitleAlignment.top,
          contentPadding: EdgeInsets.zero,
          horizontalTitleGap: 12,
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
                  child: Obx(() {
                    final user = c.user.value;
                    final currentAuthorId = c.authorId.value ?? user?.authorId;
                    final isMe = currentAuthorId != null &&
                        currentAuthorId == comment.author.authorId;
                    final isOp =
                        comment.author.login == widget.discussion.author.login;

                    return Text(
                      '${isOp ? '【楼主】 ' : ''}${isMe ? (user?.name ?? comment.author.name) : comment.author.name}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isMe ? const Color(0xFFFFBC2E) : null,
                        fontWeight: isMe ? FontWeight.bold : null,
                        fontSize: 14,
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Lv.${comment.author.level ?? 1}',
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
                    if (comment.author.login == owner) const MyChip('绳网创始人'),
                    if (collaborators.contains(comment.author.login))
                      const MyChip('绳网协作者'),
                  ],
                ),
              ),
            ],
          ),
          trailing: Obx(() {
            final user = c.user.value;
            final currentAuthorId = c.authorId.value ?? user?.authorId;
            final isMe = currentAuthorId != null &&
                currentAuthorId == comment.author.authorId;
            return Card(
              color: isMe
                  ? const Color(0xFFFFBC2E)
                  : const Color.fromARGB(255, 96, 96, 95),
              margin: const EdgeInsets.only(right: 9, left: 4),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.zero,
                  topRight: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
                child: Text('F${index + 1}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 3, 3, 3))),
              ),
            );
          }),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              SelectionArea(
                child: HtmlWidget(
                  comment.bodyHTML,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    color: Color(0xffE0E0E0), // Force light grey color
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
                      comment.createdAt,
                      fallbackPattern: 'yyyy-MM-dd HH:mm',
                    ),
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(width: 8),
                  _buildCommentLikeButton(comment),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => widget.onReply?.call(
                        comment.id, comment.author.name,
                        addPrefix: false),
                    style: ButtonStyle(
                      padding: WidgetStateProperty.all(EdgeInsets.zero),
                      minimumSize: WidgetStateProperty.all(Size.zero),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      overlayColor: WidgetStateProperty.resolveWith<Color?>(
                        (Set<WidgetState> states) {
                          if (states.contains(WidgetState.hovered)) {
                            return const Color(0xffD7FF00)
                                .withValues(alpha: 0.1);
                          }
                          return null;
                        },
                      ),
                      foregroundColor: WidgetStateProperty.resolveWith<Color>(
                        (Set<WidgetState> states) {
                          if (states.contains(WidgetState.hovered)) {
                            return const Color(0xffD7FF00);
                          }
                          return Colors.grey;
                        },
                      ),
                    ),
                    child: const Text('回复', style: TextStyle(fontSize: 12)),
                  ),
                  Obx(() {
                    final user = c.user.value;
                    final currentAuthorId = c.authorId.value ?? user?.authorId;
                    final isMe = currentAuthorId != null &&
                        currentAuthorId == comment.author.authorId;
                    if (!isMe) return const SizedBox.shrink();

                    final deleting = _deletingCommentIds.contains(comment.id);
                    return Row(
                      children: [
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed:
                              deleting ? null : () => _deleteComment(comment),
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
                        ),
                      ],
                    );
                  }),
                ],
              ),
              Replies(
                  comment: comment,
                  discussion: widget.discussion,
                  onDelete: _deleteComment,
                  removingCommentIds: _removingCommentIds,
                  onCollapseScrollToParent: () {
                    Scrollable.ensureVisible(
                      itemContext,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      alignment: 0.0,
                    );
                  },
                  onReply: (id, userName, {addPrefix = false}) =>
                      widget.onReply?.call(id, userName, addPrefix: addPrefix)),
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

        return _buildCommentRemovalAnimation(comment, content);
      },
    );
  }

  Widget _buildMobileCommentItem(CommentModel comment, int index) {
    final baseTitleStyle =
        Theme.of(context).textTheme.titleMedium ?? const TextStyle();

    return Builder(
      builder: (itemContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
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
                        onTap: () => launchUrlString(comment.url),
                        child: Avatar(comment.author.avatar, size: 38),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: InkWell(
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              onTap: () => launchUrlString(comment.url),
                              child: Obx(() {
                                final user = c.user.value;
                                final currentAuthorId =
                                    c.authorId.value ?? user?.authorId;
                                final isMe = currentAuthorId != null &&
                                    currentAuthorId == comment.author.authorId;
                                final isOp = comment.author.login ==
                                    widget.discussion.author.login;

                                return Text(
                                  '${isOp ? '【楼主】 ' : ''}${isMe ? (user?.name ?? comment.author.name) : comment.author.name}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: baseTitleStyle.copyWith(
                                    color: isMe
                                        ? const Color(0xFFFFBC2E)
                                        : baseTitleStyle.color,
                                    fontWeight: isMe
                                        ? FontWeight.bold
                                        : baseTitleStyle.fontWeight,
                                    fontSize: 16,
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Lv.${comment.author.level ?? 1}',
                            style: const TextStyle(
                              color: Color(0xffD7FF00),
                              fontWeight: FontWeight.bold,
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Card(
                      color: const Color.fromARGB(255, 96, 96, 95),
                      margin: EdgeInsets.zero,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.zero,
                          topRight: Radius.circular(8),
                          bottomLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 2,
                          horizontal: 10,
                        ),
                        child: Text(
                          'F${index + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 3, 3, 3),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (comment.author.login == owner ||
                    collaborators.contains(comment.author.login)) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      if (comment.author.login == owner) const MyChip('绳网创始人'),
                      if (collaborators.contains(comment.author.login))
                        const MyChip('绳网协作者'),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                SelectionArea(
                  child: HtmlWidget(
                    comment.bodyHTML,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      color: Color(0xffE0E0E0),
                    ),
                    onTapImage: (data) {
                      if (data.sources.isEmpty) return;
                      final url = data.sources.first.url;
                      ImageViewer.show(
                        context,
                        imageUrls: [url],
                        heroTagPrefix: null,
                      );
                    },
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
                              comment.createdAt,
                              fallbackPattern: 'yyyy-MM-dd HH:mm',
                            ),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                          TextButton(
                            onPressed: () => widget.onReply?.call(
                              comment.id,
                              comment.author.name,
                              addPrefix: false,
                            ),
                            style: ButtonStyle(
                              padding: WidgetStateProperty.all(EdgeInsets.zero),
                              minimumSize: WidgetStateProperty.all(Size.zero),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              overlayColor:
                                  WidgetStateProperty.resolveWith<Color?>(
                                (Set<WidgetState> states) {
                                  if (states.contains(WidgetState.hovered)) {
                                    return const Color(0xffD7FF00).withValues(
                                      alpha: 0.1,
                                    );
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
                          Obx(() {
                            final user = c.user.value;
                            final currentAuthorId =
                                c.authorId.value ?? user?.authorId;
                            final isMe = currentAuthorId != null &&
                                currentAuthorId == comment.author.authorId;
                            if (!isMe) return const SizedBox.shrink();

                            final deleting = _deletingCommentIds.contains(
                              comment.id,
                            );
                            return TextButton(
                              onPressed: deleting
                                  ? null
                                  : () => _deleteComment(comment),
                              style: ButtonStyle(
                                padding:
                                    WidgetStateProperty.all(EdgeInsets.zero),
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
                    _buildCommentLikeButton(comment),
                  ],
                ),
                Replies(
                  comment: comment,
                  discussion: widget.discussion,
                  onDelete: _deleteComment,
                  removingCommentIds: _removingCommentIds,
                  onCollapseScrollToParent: () {
                    Scrollable.ensureVisible(
                      itemContext,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      alignment: 0.0,
                    );
                  },
                  onReply: (id, userName, {addPrefix = false}) =>
                      widget.onReply?.call(id, userName, addPrefix: addPrefix),
                ),
              ],
            ),
          ),
          const Divider(thickness: 2, height: 32),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Image.asset(
            'assets/images/Bangboo.gif',
            width: 80,
            height: 80,
          ),
        ),
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 600;

    final comments =
        widget.discussion.comments.map((e) => e.nodes).flat.toList();

    if (widget.useListView) {
      return ListView.builder(
        controller: widget.controller,
        physics: widget.physics,
        padding: widget.padding,
        itemCount: comments.length + 1,
        itemBuilder: (context, index) {
          if (index == comments.length) return _buildFooter();
          return _buildCommentItem(comments[index], index, isMobile);
        },
      );
    }

    return Column(
      children: [
        ...comments.asMap().entries.map(
            (entry) => _buildCommentItem(entry.value, entry.key, isMobile)),
        _buildFooter(),
      ],
    );
  }
}
