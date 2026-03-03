import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/components/click_region.dart';
import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/dialog_helper.dart';
import 'package:inter_knot/helpers/toast.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/h_data.dart';
import 'package:inter_knot/pages/create_discussion_page.dart';

class DiscussionActionButtons extends StatefulWidget {
  const DiscussionActionButtons({
    super.key,
    required this.discussion,
    required this.hData,
    this.onCommentAdded,
    this.onEditSuccess,
  });

  final DiscussionModel discussion;
  final HDataModel hData;
  final VoidCallback? onCommentAdded;
  final VoidCallback? onEditSuccess;

  @override
  State<DiscussionActionButtons> createState() =>
      DiscussionActionButtonsState();
}

class DiscussionActionButtonsState extends State<DiscussionActionButtons>
    with SingleTickerProviderStateMixin {
  final c = Get.find<Controller>();
  late final api = Get.find<Api>();

  bool _isWriting = false;
  bool _isLoading = false;
  String? _parentId;
  String? _replyToUser;
  bool _addReplyPrefix = false;

  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final AnimationController _controller;
  late final Animation<double> _sizeAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _sizeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.value = 1.0;
  }

  Future<void> replyTo(String parentId, String? userName,
      {bool addPrefix = false}) async {
    if (!await c.ensureLogin()) return;

    setState(() {
      _parentId = parentId;
      _replyToUser = userName;
      _isWriting = true;
      _addReplyPrefix = addPrefix;
    });
    _controller.reverse();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    var content = _textController.text.trim();
    if (content.isEmpty) {
      showToast('评论内容不能为空', isError: true);
      return;
    }

    if (_addReplyPrefix && _replyToUser != null) {
      content = '回复 @$_replyToUser :$content';
    }

    if (!await c.ensureLogin()) return;

    setState(() => _isLoading = true);

    try {
      final user = c.user.value;
      final authorId = c.authorId.value ?? await c.ensureAuthorForUser(user);
      if (authorId == null || authorId.isEmpty) {
        showToast('无法关联作者，请重新登录后再试', isError: true);
        return;
      }

      final res = await api.addDiscussionComment(
        widget.discussion.id,
        content,
        authorId: authorId,
        parentId: _parentId,
      );

      if (res.hasError) throw Exception(res.statusText ?? 'Unknown error');

      if (res.body?['errors'] != null) {
        final errors = res.body!['errors'] as List<dynamic>;
        if (errors.isNotEmpty) {
          final first = errors[0];
          final msg = first is Map ? first['message']?.toString() : null;
          throw Exception(msg ?? 'Failed to add comment');
        }
      }

      _textController.clear();
      _cancel();

      // 清空评论列表并重置分页状态
      widget.discussion.comments.clear();
      widget.discussion.commentsCount++;
      
      // 强制刷新评论列表
      await widget.discussion.fetchComments();
      
      // 强制刷新UI
      if (mounted) setState(() {});
      
      // 通知父组件刷新UI
      widget.onCommentAdded?.call();
      
      showToast('评论发布成功');
    } catch (e) {
      showToast('评论发布失败: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleTap() async {
    if (!await c.ensureLogin()) return;

    if (_isWriting) {
      _submit();
    } else {
      setState(() => _isWriting = true);
      _controller.reverse();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  void _cancel() {
    setState(() {
      _isWriting = false;
      _parentId = null;
      _replyToUser = null;
      _addReplyPrefix = false;
    });
    _textController.clear();
    _controller.forward();
    _focusNode.unfocus();
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDeleteConfirmDialog(
      context: context,
      title: '确认删除',
      message: '确定要删除这个帖子吗？此操作不可恢复。',
      width: 300,
    );

    if (confirmed == true) {
      try {
        final res = await api.deleteDiscussion(widget.discussion.id);
        if (res.hasError) {
          showToast('删除失败: ${res.statusText}', isError: true);
        } else {
          if (!mounted) return;
          Navigator.of(context).pop(true);
          showToast('帖子已删除');
          c.searchResult.refresh();
          c.bookmarks.refresh();
          c.history.refresh();
        }
      } catch (e) {
        showToast('删除出错: $e', isError: true);
      }
    }
  }

  void _handleEdit() async {
    final result = await CreateDiscussionPage.show(
      context,
      discussion: widget.discussion,
    );
    if (result == true) {
      widget.onEditSuccess?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapOutside: (_) {
        if (_isWriting) _cancel();
      },
      child: Row(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xff222222),
                borderRadius: BorderRadius.circular(maxRadius),
                border: Border.all(color: const Color(0xff2D2D2D), width: 4),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final fullWidth = constraints.maxWidth;
                  const iconWidth = 48.0;

                  return AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final progress = 1.0 - _controller.value;
                      final curve = Curves.easeInOut.transform(progress);

                      final inputWidth = (fullWidth - iconWidth) * curve;
                      final buttonWidth = fullWidth - inputWidth;

                      return Row(
                        children: [
                          SizedBox(
                            width: inputWidth,
                            child: ClipRect(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                widthFactor: 1.0,
                                child: UnconstrainedBox(
                                  alignment: Alignment.centerLeft,
                                  constrainedAxis: Axis.vertical,
                                  child: SizedBox(
                                    width: fullWidth - iconWidth,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0),
                                      child: CallbackShortcuts(
                                        bindings: {
                                          const SingleActivator(
                                                  LogicalKeyboardKey.escape):
                                              _cancel,
                                        },
                                        child: TextField(
                                          controller: _textController,
                                          focusNode: _focusNode,
                                          style: const TextStyle(
                                              fontSize: 16,
                                              color: Colors.white),
                                          cursorColor: Colors.white,
                                          decoration:
                                              InputDecoration.collapsed(
                                            hintText: _replyToUser != null
                                                ? '回复 @$_replyToUser：'
                                                : '请输入文本...',
                                            hintStyle: const TextStyle(
                                                color: Colors.grey),
                                          ),
                                          onSubmitted: (_) => _submit(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: buttonWidth,
                            child: ClickRegion(
                              onTap: _handleTap,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Opacity(
                                    opacity: curve,
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white),
                                          )
                                        : const Icon(Icons.send,
                                            key: ValueKey('send')),
                                  ),
                                  Opacity(
                                    opacity: 1.0 - curve,
                                    child: Transform.translate(
                                      offset: Offset(-50 * curve, 0),
                                      child: UnconstrainedBox(
                                        constrainedAxis: Axis.vertical,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.add_comment_outlined),
                                            SizedBox(width: 8),
                                            Text(
                                              '评论',
                                              style: TextStyle(fontSize: 16),
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              widget.discussion.commentsCount
                                                  .toString(),
                                              style: TextStyle(fontSize: 16),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _sizeAnimation,
            axis: Axis.horizontal,
            axisAlignment: -1.0,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Obx(() {
                    final isLiked = c.bookmarks
                        .map((e) => e.id)
                        .contains(widget.discussion.id);
                    return Tooltip(
                      message: isLiked ? '不喜欢' : '喜欢',
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xff222222),
                          borderRadius: BorderRadius.circular(maxRadius),
                          border: Border.all(
                              color: const Color(0xff2D2D2D), width: 4),
                        ),
                        child: ClickRegion(
                          onTap: () => c.toggleFavorite(widget.hData),
                          child: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_outline,
                            color: isLiked ? Colors.red : null,
                          ),
                        ),
                      ),
                    );
                  }),
                  if (c.user.value?.login ==
                      widget.discussion.author.login) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: '编辑',
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xff222222),
                          borderRadius: BorderRadius.circular(maxRadius),
                          border: Border.all(
                              color: const Color(0xff2D2D2D), width: 4),
                        ),
                        child: ClickRegion(
                          onTap: _handleEdit,
                          child: const Icon(Icons.edit, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: '删除',
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xff222222),
                          borderRadius: BorderRadius.circular(maxRadius),
                          border: Border.all(
                              color: const Color(0xff2D2D2D), width: 4),
                        ),
                        child: ClickRegion(
                          onTap: _handleDelete,
                          child: const Icon(Icons.delete, color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
