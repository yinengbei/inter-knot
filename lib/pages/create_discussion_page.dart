import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:markdown/markdown.dart' as md;

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
      final bodyHTML = md.markdownToHtml(body);

      final res = await api.createDiscussion(
          title, bodyHTML, body, cover.isEmpty ? null : cover);

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

