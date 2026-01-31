import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/controllers/data.dart';

class CreateDiscussionPage extends StatefulWidget {
  const CreateDiscussionPage({super.key});

  @override
  State<CreateDiscussionPage> createState() => _CreateDiscussionPageState();
}

class _CreateDiscussionPageState extends State<CreateDiscussionPage> {
  final titleController = TextEditingController();
  final bodyController = TextEditingController();
  final coverController = TextEditingController();

  bool isLoading = false;

  final c = Get.find<Controller>();
  late final api = Get.find<Api>();

  String _slugify(String input) {
    final normalized = input
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return normalized.isEmpty ? 'post' : normalized;
  }

  String _slugifyUnique(String input) {
    final base = _slugify(input);
    final suffix = DateTime.now().millisecondsSinceEpoch;
    return '$base-$suffix';
  }

  bool _isSlugUniqueError(Map<String, dynamic>? body) {
    final errors = body?['errors'];
    if (errors is! List || errors.isEmpty) return false;
    final first = errors.first;
    if (first is! Map) return false;
    final message = first['message']?.toString().toLowerCase() ?? '';
    if (message.contains('unique')) return true;
    final ext = first['extensions'];
    if (ext is Map) {
      final details = ext['error']?['details']?['errors'];
      if (details is List) {
        for (final item in details) {
          if (item is Map) {
            final path = item['path'];
            final msg = item['message']?.toString().toLowerCase() ?? '';
            if (msg.contains('unique') ||
                (path is List && path.contains('slug'))) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  Future<void> _submit() async {
    final title = titleController.text.trim();
    final body = bodyController.text;
    final cover = coverController.text.trim();

    if (title.isEmpty) {
      Get.rawSnackbar(message: '标题不能为空');
      return;
    }
    if (body.isEmpty) {
      Get.rawSnackbar(message: '内容不能为空');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      var slug = _slugify(title);
      final user = c.user.value;
      final authorId = c.authorId.value ?? await c.ensureAuthorForUser(user);
      if (authorId == null || authorId.isEmpty) {
        throw Exception('无法关联作者，请重新登录后再试');
      }

      var res = await api.createArticle(
        title: title,
        description: body,
        slug: slug,
        coverId: cover.isEmpty ? null : cover,
        authorId: authorId,
      );

      if (res.body?['errors'] != null && _isSlugUniqueError(res.body)) {
        slug = _slugifyUnique(title);
        res = await api.createArticle(
          title: title,
          description: body,
          slug: slug,
          coverId: cover.isEmpty ? null : cover,
          authorId: authorId,
        );
      }

      if (res.hasError) {
        throw Exception(res.statusText ?? 'Unknown error');
      }

      if (res.body?['errors'] != null) {
        throw Exception(res.body!['errors'][0]['message']);
      }

      Get.back();
      Get.rawSnackbar(message: '发帖成功');
      // Refresh list
      c.refreshSearchData();
    } catch (e) {
      Get.rawSnackbar(message: '发帖失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    bodyController.dispose();
    coverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('发布新讨论'),
        actions: [
          IconButton(
            onPressed: isLoading ? null : _submit,
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: '标题',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: coverController,
              decoration: const InputDecoration(
                labelText: '封面图片 URL (可选)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: bodyController,
                decoration: const InputDecoration(
                  labelText: '内容 (支持 Markdown)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
