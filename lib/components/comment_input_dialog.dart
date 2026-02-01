import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/pages/login_page.dart';

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
      Get.rawSnackbar(message: '评论内容不能为空'.tr);
      return;
    }

    if (!c.isLogin.value) {
      Get.back();
      Get.to(() => const LoginPage());
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      if (widget.discussionId.isEmpty) {
        Get.rawSnackbar(message: '讨论 ID 无效'.tr);
        return;
      }
      
      final user = c.user.value;
      final authorId = c.authorId.value ?? await c.ensureAuthorForUser(user);
      if (authorId == null || authorId.isEmpty) {
        Get.rawSnackbar(message: '无法关联作者，请重新登录后再试'.tr);
        return;
      }
      
      print('Submitting comment for discussion: ${widget.discussionId}, author: $authorId');
      final res = await api.addDiscussionComment(
        widget.discussionId,
        content,
        authorId: authorId,
      );

      if (res.hasError) {
        throw Exception(res.statusText ?? 'Unknown error');
      }

      if (res.body?['errors'] != null) {
        final errors = res.body!['errors'] as List;
        if (errors.isNotEmpty) {
          throw Exception(errors[0]['message'] ?? 'Failed to add comment');
        }
      }

      Get.back();
      Get.rawSnackbar(message: '评论发布成功'.tr);
      widget.onCommentAdded();
    } catch (e) {
      Get.rawSnackbar(message: '评论发布失败: $e'.tr);
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
                Expanded(
                  child: Text(
                    '写评论'.tr,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: isLoading ? null : () => Get.back(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: commentController,
                decoration: InputDecoration(
                  hintText: '输入你的评论...'.tr,
                  border: const OutlineInputBorder(),
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
                  onPressed: isLoading ? null : () => Get.back(),
                  child: Text('取消'.tr),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('发布'.tr),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

