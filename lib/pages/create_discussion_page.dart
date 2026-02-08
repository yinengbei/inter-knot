import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/components/avatar.dart';
import 'package:inter_knot/components/click_region.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/gen/assets.gen.dart';
import 'package:inter_knot/helpers/web_hooks.dart';
import 'package:markdown_quill/markdown_quill.dart';
import 'package:inter_knot/helpers/normalize_markdown.dart';

class CreateDiscussionPage extends StatefulWidget {
  const CreateDiscussionPage({super.key});

  @override
  State<CreateDiscussionPage> createState() => _CreateDiscussionPageState();
}

class _CreateDiscussionPageState extends State<CreateDiscussionPage> {
  final titleController = TextEditingController();
  final _quillController = quill.QuillController.basic();

  // Images State
  final RxList<({String id, String url})> _uploadedImages =
      <({String id, String url})>[].obs;
  bool _isCoverUploading = false;

  bool isLoading = false;
  int _selectedIndex = 0;

  final c = Get.find<Controller>();
  late final api = Get.find<Api>();

  /// 设置粘贴事件监听
  void _setupPasteListener() {
    setupPasteListener((filename, bytes, mimeType) {
      // 在光标位置插入占位符并开始上传
      final index = _quillController.selection.start;
      _uploadImageAndInsert(
        insertIndex: index,
        filename: filename,
        bytes: bytes,
        mimeType: mimeType,
      );
    });
  }

  /// 粘贴图片 -> 上传 -> 替换为 HTML 图片标签
  void _uploadImageAndInsert({
    required int insertIndex,
    required String filename,
    required Uint8List bytes,
    required String mimeType,
  }) {
    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    final token = '{{uploading:$taskId}}';

    // 插入占位符并移动光标到占位符后
    _quillController.replaceText(
      insertIndex,
      0,
      token,
      TextSelection.collapsed(offset: insertIndex + token.length),
    );

    _uploadAndReplace(
        token: token, filename: filename, bytes: bytes, mimeType: mimeType);
  }

  Future<void> _uploadAndReplace({
    required String token,
    required String filename,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    try {
      final result = await api.uploadImage(
        bytes: bytes,
        filename: filename,
        mimeType: mimeType,
        onProgress: (_) {},
      );

      if (result == null) {
        _replaceToken(token, '上传失败：$filename (服务器无响应)');
        return;
      }

      // 从服务器响应获取数据
      final url = result['url'] as String?;
      if (url == null) {
        _replaceToken(token, '上传失败：$filename (无URL)');
        return;
      }

      // 构建完整 URL
      final fullUrl =
          url.startsWith('http') ? url : '${api.httpClient.baseUrl}$url';

      // 使用 Quill Image Embed
      _replaceTokenWithImage(token, fullUrl);
    } catch (e) {
      _replaceToken(token, '上传失败：$filename ($e)');
    }
  }

  void _replaceTokenWithImage(String token, String imageUrl) {
    final index = _findTokenIndex(token);
    if (index == null) return;

    // 先删除 token
    _quillController.replaceText(
      index,
      token.length,
      '',
      TextSelection.collapsed(offset: index),
    );

    // 插入图片 Embed
    // 默认设置图片大小为 160px，以匹配封面上传样式
    _quillController.document.insert(index, quill.BlockEmbed.image(imageUrl));
    _quillController.formatText(index, 1,
        const quill.Attribute('width', quill.AttributeScope.ignore, '160'));
    _quillController.formatText(index, 1,
        const quill.Attribute('height', quill.AttributeScope.ignore, '160'));
    _quillController.formatText(
        index,
        1,
        const quill.Attribute('style', quill.AttributeScope.ignore,
            'display: inline; margin: 0 0 1em 0'));

    // 移动光标到图片后 (Embed 长度为 1)
    _quillController.updateSelection(
      TextSelection.collapsed(offset: index + 1),
      quill.ChangeSource.local,
    );
  }

  void _replaceToken(String token, String replacement) {
    final index = _findTokenIndex(token);
    if (index == null) return;

    // 先删除 token，再插入 HTML，避免转义导致的替换错位
    _quillController.replaceText(
      index,
      token.length,
      '',
      TextSelection.collapsed(offset: index),
    );
    _quillController.replaceText(
      index,
      0,
      replacement,
      TextSelection.collapsed(offset: index + replacement.length),
    );
    _quillController.updateSelection(
      TextSelection.collapsed(offset: index + replacement.length),
      quill.ChangeSource.local,
    );
  }

  int? _findTokenIndex(String token) {
    final delta = _quillController.document.toDelta();
    final buffer = StringBuffer();
    for (final op in delta.toList()) {
      final data = op.data;
      if (data is String) {
        buffer.write(data);
      } else {
        // embeds count as length 1 in document indices
        buffer.write('\uFFFC');
      }
    }
    final text = buffer.toString();
    final pos = text.indexOf(token);
    if (pos == -1) return null;
    return pos;
  }

  Future<void> _pickImages() async {
    if (_isCoverUploading) return;
    if (_uploadedImages.length >= 9) {
      Get.rawSnackbar(message: '最多上传 9 张图片');
      return;
    }

    final picker = ImagePicker();
    // Allow multiple selection
    final files = await picker.pickMultiImage();
    if (files.isEmpty) return;

    // Filter by count
    final remaining = 9 - _uploadedImages.length;
    final toUpload = files.take(remaining).toList();

    setState(() {
      _isCoverUploading = true;
    });

    try {
      for (final file in toUpload) {
        // Check size (15MB)
        final len = await file.length();
        if (len > 15 * 1024 * 1024) {
          Get.rawSnackbar(message: '图片 ${file.name} 超过 15MB，已跳过');
          continue;
        }

        final bytes = await file.readAsBytes();
        final mimeType = file.mimeType ?? 'image/jpeg';

        final result = await api.uploadImage(
          bytes: bytes,
          filename: file.name,
          mimeType: mimeType,
          onProgress: (_) {},
        );

        if (result != null) {
          final id = result['id'];
          final url = result['url'] as String?;

          if (id != null && url != null) {
            final fullUrl =
                url.startsWith('http') ? url : '${api.httpClient.baseUrl}$url';
            _uploadedImages.add((id: id.toString(), url: fullUrl));
          }
        }
      }
    } catch (e) {
      debugPrint('Upload images failed: $e');
      Get.rawSnackbar(message: '上传出错: $e');
    } finally {
      setState(() {
        _isCoverUploading = false;
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final filename = file.name;
    final mimeType = file.mimeType ?? 'image/jpeg';

    final index = _quillController.selection.start;
    _uploadImageAndInsert(
      insertIndex: index,
      filename: filename,
      bytes: bytes,
      mimeType: mimeType,
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    _quillController.dispose();
    if (kIsWeb) {
      removePasteListener();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // 设置 Web 平台剪贴板粘贴监听
    if (kIsWeb) {
      _setupPasteListener();
    }
  }

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
    if (body == null) return false;

    // Check for Strapi v5 REST error format
    final error = body['error'];
    if (error is Map) {
      final message = error['message']?.toString().toLowerCase() ?? '';
      if (message.contains('unique') || message.contains('slug')) return true;

      final details = error['details'];
      if (details is Map) {
        final errors = details['errors'];
        if (errors is List) {
          for (final item in errors) {
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

    // Fallback for GraphQL style (if any legacy code remains)
    final errors = body['errors'];
    if (errors is! List || errors.isEmpty) return false;
    final first = errors.first;
    if (first is! Map) return false;
    final message = first['message']?.toString().toLowerCase() ?? '';
    if (message.contains('unique')) return true;
    final ext = first['extensions'];
    if (ext is Map<String, dynamic>) {
      final error = ext['error'];
      final details =
          error is Map ? (error as Map<String, dynamic>)['details'] : null;
      final errList =
          details is Map ? (details as Map<String, dynamic>)['errors'] : null;
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
    final markdownText = normalizeMarkdown(DeltaToMarkdown().convert(delta));

    // Pass all uploaded images as cover
    // If backend supports multiple, we send list.
    // If backend only supports single, we send first one.
    dynamic finalCoverId;
    if (_uploadedImages.isNotEmpty) {
      if (_uploadedImages.length == 1) {
        finalCoverId = _uploadedImages.first.id;
      } else {
        finalCoverId = _uploadedImages.map((e) => e.id).toList();
      }
    }

    if (title.isEmpty) {
      Get.rawSnackbar(message: '标题不能为空');
      return;
    }
    // Content check: either text or images must exist
    if (markdownText.trim().isEmpty && _uploadedImages.isEmpty) {
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
        text: markdownText,
        slug: slug,
        coverId: finalCoverId,
        authorId: authorId,
      );

      // Check for error in REST format (error object) or GraphQL format (errors list)
      final resBody = res.body;
      if (resBody != null) {
        final error = resBody['error'];
        final errors = resBody['errors'];
        if ((error != null || errors != null) && _isSlugUniqueError(resBody)) {
          slug = _slugifyUnique(title);
          res = await api.createArticle(
            title: title,
            text: markdownText,
            slug: slug,
            coverId: finalCoverId,
            authorId: authorId,
          );
        }
      }

      if (res.hasError) {
        // Try to extract Strapi error message
        final errorBody = res.body;
        String? msg;
        if (errorBody != null) {
          final error = errorBody['error'];
          final errors = errorBody['errors'];
          if (error is Map) {
            msg = error['message']?.toString();
          } else if (errors is List && errors.isNotEmpty) {
            final first = errors.first;
            if (first is Map) {
              msg = first['message']?.toString();
            }
          }
        }
        throw Exception(msg ?? res.statusText ?? 'Unknown error');
      }

      // Final check for business logic errors even if status is 200
      final successBody = res.body;
      if (successBody != null) {
        final errors = successBody['errors'];
        if (errors != null && errors is List) {
          final first = errors.isNotEmpty ? errors[0] : null;
          final msg = first is Map ? first['message']?.toString() : null;
          throw Exception(msg ?? 'Unknown error');
        } else {
          final error = successBody['error'];
          if (error != null && error is Map) {
            final msg = error['message']?.toString();
            throw Exception(msg ?? 'Unknown error');
          }
        }
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
              config: quill.QuillSimpleToolbarConfig(
                showFontFamily: false,
                showFontSize: false,
                showSearchButton: false,
                showSubscript: false,
                showSuperscript: false,
                showColorButton: false,
                showBackgroundColorButton: false,
                toolbarIconAlignment: WrapAlignment.start,
                multiRowsDisplay: false,
                customButtons: [
                  quill.QuillToolbarCustomButtonOptions(
                    icon: const Icon(Icons.image),
                    onPressed: _pickAndUploadImage,
                  ),
                ],
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
                  config: quill.QuillEditorConfig(
                    placeholder: '请输入文本',
                    padding: const EdgeInsets.all(16),
                    embedBuilders: FlutterQuillEmbeds.editorBuilders(
                      imageEmbedConfig: QuillEditorImageEmbedConfig(
                        onImageClicked: (url) {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Column(
          children: [
            Expanded(
              child: Obx(() {
                final images = _uploadedImages;
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 160,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                  ),
                  itemCount: images.length + (images.length < 9 ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == images.length) {
                      // Add Button
                      return GestureDetector(
                        onTap: _pickImages,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xff313132),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: const Color(0xff1E1E1E),
                          ),
                          child: _isCoverUploading
                              ? const Center(child: CircularProgressIndicator())
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add,
                                        size: 32, color: Colors.grey),
                                    SizedBox(height: 4),
                                    Text(
                                      '添加图片',
                                      style: TextStyle(
                                          color: Colors.grey, fontSize: 12),
                                    ),
                                  ],
                                ),
                        ),
                      );
                    }

                    final img = images[index];
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            img.url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child:
                                  Icon(Icons.broken_image, color: Colors.grey),
                            ),
                          ),
                        ),
                        // Delete Button
                        Positioned(
                          right: 4,
                          top: 4,
                          child: InkWell(
                            onTap: () {
                              _uploadedImages.removeAt(index);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                        // Cover Label for first item
                        if (index == 0)
                          Positioned(
                            left: 4,
                            top: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '封面',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xff121212),
      bottomNavigationBar: isDesktop
          ? null
          : Container(
              color: const Color(0xff1A1A1A),
              height: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: InkWell(
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      onTap: () {
                        setState(() {
                          _selectedIndex = 0;
                        });
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _selectedIndex == 0
                                ? Icons.article
                                : Icons.article_outlined,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '正文',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: Material(
                      color: const Color(0xffFBC02D),
                      shape: const CircleBorder(),
                      child: InkWell(
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        customBorder: const CircleBorder(),
                        onTap: isLoading ? null : _submit,
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: isLoading
                              ? const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                )
                              : const Icon(Icons.send, color: Colors.black),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      onTap: () {
                        setState(() {
                          _selectedIndex = 1;
                        });
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _selectedIndex == 1
                                ? Icons.image
                                : Icons.image_outlined,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '图片',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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
                        SizedBox(
                          width: 180,
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
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    minLeadingWidth: 0,
                                    horizontalTitleGap: 8,
                                    contentPadding:
                                        const EdgeInsets.symmetric(horizontal: 8),
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
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    minLeadingWidth: 0,
                                    horizontalTitleGap: 8,
                                    contentPadding:
                                        const EdgeInsets.symmetric(horizontal: 8),
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
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
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
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Material(
                                      color: const Color(0xff1A1A1A),
                                      borderRadius: BorderRadius.circular(28),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(28),
                                        onTap: isLoading ? null : _submit,
                                        child: Container(
                                          height: 56,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 24),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(4),
                                                decoration: const BoxDecoration(
                                                  color: Color(0xffFBC02D),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: isLoading
                                                    ? const SizedBox(
                                                        width: 16,
                                                        height: 16,
                                                        child:
                                                            CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.black,
                                                        ),
                                                      )
                                                    : const Icon(
                                                        Icons.send,
                                                        color: Colors.black,
                                                        size: 16,
                                                      ),
                                              ),
                                              const SizedBox(width: 12),
                                              const Text(
                                                '发布',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
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
