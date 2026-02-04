import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/components/avatar.dart';
import 'package:inter_knot/components/click_region.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/gen/assets.gen.dart';
import 'package:markdown_quill/markdown_quill.dart';

class CreateDiscussionPage extends StatefulWidget {
  const CreateDiscussionPage({super.key});

  @override
  State<CreateDiscussionPage> createState() => _CreateDiscussionPageState();
}

class _CreateDiscussionPageState extends State<CreateDiscussionPage> {
  final titleController = TextEditingController();
  final _quillController = quill.QuillController.basic();
  final coverController = TextEditingController();

  bool isLoading = false;
  int _selectedIndex = 0;

  final c = Get.find<Controller>();
  late final api = Get.find<Api>();

  String _slugify(String input) {
    final normalized = input
        .toLowerCase()
        .trim()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp('-{2,}'), '-')
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
    if (ext is Map<String, dynamic>) {
      final error = ext['error'];
      final details = error is Map ? (error as Map<String, dynamic>)['details'] : null;
      final errList = details is Map ? (details as Map<String, dynamic>)['errors'] : null;
      if (errList is List) {
        for (final item in errList) {
          if (item is Map<String, dynamic>) {
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
    final delta = _quillController.document.toDelta();
    final body = DeltaToMarkdown().convert(delta);
    final cover = coverController.text.trim();

    if (title.isEmpty) {
      Get.rawSnackbar(message: '标题不能为空');
      return;
    }
    if (_quillController.document.isEmpty()) {
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
        text: body,
        slug: slug,
        coverId: cover.isEmpty ? null : cover,
        authorId: authorId,
      );

      if (res.body?['errors'] != null && _isSlugUniqueError(res.body)) {
        slug = _slugifyUnique(title);
        res = await api.createArticle(
          title: title,
          text: body,
          slug: slug,
          coverId: cover.isEmpty ? null : cover,
          authorId: authorId,
        );
      }

      if (res.hasError) {
        throw Exception(res.statusText ?? 'Unknown error');
      }

      if (res.body?['errors'] != null) {
        final errors = res.body!['errors'] as List<dynamic>;
        final first = errors.isNotEmpty ? errors[0] : null;
        final msg = first is Map ? first['message']?.toString() : null;
        throw Exception(msg ?? 'Unknown error');
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
    _quillController.dispose();
    coverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isDesktop = screenW >= 600;

    final content = IndexedStack(
      index: _selectedIndex,
      children: [
        Column(
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: '标题',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            quill.QuillSimpleToolbar(
              controller: _quillController,
              config: const quill.QuillSimpleToolbarConfig(
                showFontFamily: false,
                showFontSize: false,
                showSearchButton: false,
                showSubscript: false,
                showSuperscript: false,
                showColorButton: false,
                showBackgroundColorButton: false,
                toolbarIconAlignment: WrapAlignment.start,
                multiRowsDisplay: false,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: quill.QuillEditor.basic(
                  controller: _quillController,
                  config: const quill.QuillEditorConfig(
                    placeholder: '请输入文本',
                    padding: EdgeInsets.all(16),
                  ),
                ),
              ),
            ),
          ],
        ),
        Column(
          children: [
            TextField(
              controller: coverController,
              decoration: const InputDecoration(
                labelText: '封面图片 URL (可选)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xff121212),
      bottomNavigationBar: isDesktop
          ? null
          : BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.article_outlined),
                  label: '正文',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.image_outlined),
                  label: '图片',
                ),
              ],
            ),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: Assets.images.discussionPageBgPoint.provider(),
                  repeat: ImageRepeat.repeat,
                ),
                gradient: const LinearGradient(
                  colors: [Color(0xff161616), Color(0xff080808)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomLeft,
                ),
              ),
              child: Row(
                children: [
                  Obx(() {
                    final user = c.user.value;
                    return Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xff2D2D2D),
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Avatar(
                        user?.avatar,
                        onTap: c.isLogin.value ? c.pickAndUploadAvatar : null,
                      ),
                    );
                  }),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '发布委托',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ClickRegion(
                    child: Assets.images.closeBtn.image(),
                    onTap: () => Get.back(),
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: isDesktop
                  ? Row(
                      children: [
                                    Expanded(
                                      child: Container(
                            margin: const EdgeInsets.only(
                              top: 16,
                              left: 16,
                              right: 8,
                              bottom: 16,
                            ),
                            height: double.infinity,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xff313132),
                                width: 4,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: ListView(
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.article_outlined),
                                    title: const Text('正文'),
                                    selected: _selectedIndex == 0,
                                    onTap: () {
                                      setState(() {
                                        _selectedIndex = 0;
                                      });
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.image_outlined),
                                    title: const Text('图片'),
                                    selected: _selectedIndex == 1,
                                    onTap: () {
                                      setState(() {
                                        _selectedIndex = 1;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                                    Expanded(
                                      flex: 9,
                                      child: Column(
                                        children: [
                                          Expanded(
                                            child: Container(
                                              margin: const EdgeInsets.only(
                                                top: 16,
                                                left: 8,
                                                right: 16,
                                                bottom: 8,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xff070707),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(16.0),
                                                child: content,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            margin: const EdgeInsets.only(
                                              left: 8,
                                              right: 16,
                                              bottom: 16,
                                            ),
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: const Color(0xff070707),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                FilledButton.icon(
                                                  onPressed:
                                                      isLoading ? null : _submit,
                                                  style: FilledButton.styleFrom(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 24,
                                                      vertical: 16,
                                                    ),
                                                  ),
                                                  icon: isLoading
                                                      ? const SizedBox(
                                                          width: 20,
                                                          height: 20,
                                                          child:
                                                              CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      2,
                                                                  color: Colors
                                                                      .white))
                                                      : const Icon(Icons.send),
                                                  label: const Text('发布'),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: content,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
