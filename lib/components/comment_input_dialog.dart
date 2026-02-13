import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/controllers/data.dart';

class CommentInputDialog extends StatefulWidget {
  const CommentInputDialog({
    super.key,
    required this.discussionId,
    required this.onCommentAdded,
  });

  final String discussionId;
  final VoidCallback onCommentAdded;

  @override
  State<CommentInputDialog> createState() => _CommentInputDialogState();
}

class _CommentInputDialogState extends State<CommentInputDialog> {
  final commentController = TextEditingController();
  final c = Get.find<Controller>();
  late final api = Get.find<Api>();
  bool isLoading = false;

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = commentController.text.trim();

    if (content.isEmpty) {
      Get.rawSnackbar(message: '评论内容不能为空');
      return;
    }

    if (!await c.ensureLogin()) return;

    setState(() {
      isLoading = true;
    });

    try {
      if (widget.discussionId.isEmpty) {
        Get.rawSnackbar(message: '讨论 ID 无效');
        return;
      }

      final user = c.user.value;
      final authorId = c.authorId.value ?? await c.ensureAuthorForUser(user);
      if (authorId == null || authorId.isEmpty) {
        Get.rawSnackbar(message: '无法关联作者，请重新登录后再试');
        return;
      }

      debugPrint(
          'Submitting comment for discussion: ${widget.discussionId}, author: $authorId');
      final res = await api.addDiscussionComment(
        widget.discussionId,
        content,
        authorId: authorId,
      );

      if (res.hasError) {
        throw Exception(res.statusText ?? 'Unknown error');
      }

      if (res.body?['errors'] != null) {
        final errors = res.body!['errors'] as List<dynamic>;
        if (errors.isNotEmpty) {
          final first = errors[0];
          final msg = first is Map ? first['message']?.toString() : null;
          throw Exception(msg ?? 'Failed to add comment');
        }
      }

      Get.back();
      Get.rawSnackbar(message: '评论发布成功');
      widget.onCommentAdded();
    } catch (e) {
      Get.rawSnackbar(message: '评论发布失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xff222222),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          maxWidth: 600,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '写评论',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  icon: const Icon(Icons.close),
                  onPressed: isLoading ? null : () => Get.back(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  hintText: '输入你的评论...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                enabled: !isLoading,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  style: const ButtonStyle(
                    overlayColor: WidgetStatePropertyAll(Colors.transparent),
                  ),
                  onPressed: isLoading ? null : () => Get.back(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: const ButtonStyle(
                    overlayColor: WidgetStatePropertyAll(Colors.transparent),
                  ),
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('发布'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
