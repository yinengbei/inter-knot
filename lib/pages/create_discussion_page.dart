import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// 用于取消订阅粘贴事件
  html.EventListener? _pasteEventListener;

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

  /// 设置粘贴事件监听
  void _setupPasteListener() {
    _pasteEventListener = (event) {
      _handlePasteEvent(event as html.ClipboardEvent);
    };
    html.window.addEventListener('paste', _pasteEventListener);
  }

  /// 处理粘贴事件
  Future<void> _handlePasteEvent(html.ClipboardEvent event) async {
    final items = event.clipboardData?.items;
    if (items == null || items.length == 0) return;

    final length = items.length!;
    for (var i = 0; i < length; i++) {
      final item = items[i];
      final mimeType = item.type;

      // 检查是否是图片类型
      if (mimeType != null && mimeType.startsWith('image/')) {
        // 阻止默认粘贴行为
        event.preventDefault();

        final file = item.getAsFile();
        if (file == null) continue;

        try {
          // 读取文件数据
          final bytes = await _readFileAsBytes(file);
          final filename = file.name;

          // 在光标位置插入占位符并开始上传
          final index = _quillController.selection.start;

          // 开始上传
          _uploadImageAndInsert(
            insertIndex: index,
            filename: filename,
            bytes: bytes,
            mimeType: mimeType,
          );
        } catch (e) {
          debugPrint('Failed to handle pasted image: $e');
          Get.rawSnackbar(message: '图片处理失败: $e');
        }
      }
    }
  }

  /// 读取文件为 Uint8List
  Future<Uint8List> _readFileAsBytes(html.File file) async {
    final completer = Completer<Uint8List>();
    final reader = html.FileReader();

    reader.onLoadEnd.listen((event) {
      final result = reader.result;
      if (result is Uint8List) {
        completer.complete(result);
      } else if (result is ByteBuffer) {
        completer.complete(Uint8List.view(result));
      } else {
        completer.completeError('Invalid file data');
      }
    });

    reader.onError.listen((event) {
      completer.completeError('File read error');
    });

    reader.readAsArrayBuffer(file);
    return completer.future;
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

    _uploadAndReplace(token: token, filename: filename, bytes: bytes, mimeType: mimeType);
  }

  Future<void> _uploadAndReplace({
    required String token,
    required String filename,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    try {
      final result = await api.uploadImageWeb(
        bytes: bytes,
        filename: filename,
        mimeType: mimeType,
        onProgress: (_) {},
      );

      if (result == null) {
        _replaceToken(token, '![上传失败：$filename (服务器无响应)]()');
        return;
      }

      // 从服务器响应获取数据
      final url = result['url'] as String?;
      if (url == null) {
        _replaceToken(token, '![上传失败：$filename (无URL)]()');
        return;
      }

      // 构建完整 URL（已经是完整 URL，无需拼接）
      final fullUrl = url;

      // 从文件名提取基础名（不含扩展名）
      final baseName = filename.contains('.')
          ? filename.substring(0, filename.lastIndexOf('.'))
          : filename;

      // 构建 HTML img 标签（用户需求）
      final imgHtml = '<img alt="$baseName" src="$fullUrl" />';
      _replaceToken(token, imgHtml);
    } catch (e) {
      _replaceToken(token, '![上传失败：$filename ($e)]()');
    }
  }

  void _replaceToken(String token, String replacement) {
    final index = _findTokenIndex(token);
    if (index == null) return;

    _quillController.replaceText(
      index,
      token.length,
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

  Future<void> _submit() async {
    final title = titleController.text.trim();
    final delta = _quillController.document.toDelta();
    final markdownText = DeltaToMarkdown().convert(delta);
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
        text: markdownText,
        slug: slug,
        coverId: cover.isEmpty ? null : cover,
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
            coverId: cover.isEmpty ? null : cover,
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

  @override
  void initState() {
    super.initState();
    // 设置 Web 平台剪贴板粘贴监听
    _setupPasteListener();
  }

  @override
  void dispose() {
    // 移除粘贴事件监听
    if (_pasteEventListener != null) {
      html.window.removeEventListener('paste', _pasteEventListener);
    }

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
          : Container(
              color: const Color(0xff1A1A1A),
              height: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: InkWell(
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
                                                padding: const EdgeInsets.all(4),
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
