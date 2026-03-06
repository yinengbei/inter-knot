import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/dialog_helper.dart';
import 'package:inter_knot/helpers/drop_zone.dart';
import 'package:inter_knot/helpers/image_compress_helper.dart';
import 'package:inter_knot/helpers/normalize_markdown.dart';
import 'package:inter_knot/helpers/toast.dart';
import 'package:inter_knot/helpers/upload_task.dart';
import 'package:inter_knot/helpers/web_hooks.dart';
import 'package:inter_knot/models/captcha.dart';
import 'package:markdown_quill/markdown_quill.dart';

import 'package:inter_knot/pages/create_discussion/create_discussion_desktop_footer.dart';
import 'package:inter_knot/pages/create_discussion/create_discussion_desktop_sidebar.dart';
import 'package:inter_knot/pages/create_discussion/create_discussion_cover_page.dart';
import 'package:inter_knot/pages/create_discussion/create_discussion_editor_page.dart';
import 'package:inter_knot/pages/create_discussion/create_discussion_header.dart';
import 'package:inter_knot/pages/create_discussion/create_discussion_mobile_nav.dart';

import 'package:inter_knot/models/discussion.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:inter_knot/services/captcha_service.dart';

class CreateDiscussionPage extends StatefulWidget {
  const CreateDiscussionPage({super.key, this.discussion});

  final DiscussionModel? discussion;

  static Future<bool?> show(BuildContext context,
      {DiscussionModel? discussion}) {
    return showZZZDialog<bool>(
      context: context,
      pageBuilder: (context) {
        return CreateDiscussionPage(discussion: discussion);
      },
    );
  }

  @override
  State<CreateDiscussionPage> createState() => _CreateDiscussionPageState();
}

class _CreateDiscussionPageState extends State<CreateDiscussionPage> {
  static const _maxCoverImages = 9;
  static const _maxImageBytes = 15 * 1024 * 1024;
  static const _allowedImageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];

  final PageController _pageController = PageController();
  final titleController = TextEditingController();
  final _mobileBodyController = TextEditingController();
  final _quillController = quill.QuillController.basic();

  // Images State — each image is tracked as an UploadTask with its own status/progress
  final RxList<UploadTask> _uploadTasks = <UploadTask>[].obs;
  bool _isDragging = false;  // 拖拽状态

  // 压缩是 CPU 密集型任务：限制并发，避免 UI 卡顿（Web 单线程更明显）
  final Queue<Completer<void>> _compressionWaiters = Queue<Completer<void>>();
  int _activeCompressionCount = 0;

  int get _maxCompressionConcurrency => kIsWeb ? 1 : 2;

  /// 已成功上传的图片（便捷 getter）
  List<({String id, String url})> get _uploadedImages => _uploadTasks
      .where((t) => t.status.value == UploadStatus.done)
      .map((t) => (id: t.serverId!, url: t.serverUrl!))
      .toList();

  /// 是否有任何图片正在上传/压缩中
  bool get _isCoverUploading =>
      _uploadTasks.any((t) =>
          t.status.value == UploadStatus.uploading ||
          t.status.value == UploadStatus.compressing ||
          t.status.value == UploadStatus.pending);

  bool isLoading = false;
  int _selectedIndex = 0;

  final c = Get.find<Controller>();
  late final api = Get.find<Api>();

  bool _isAllowedImageFilename(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return _allowedImageExtensions.contains(ext);
  }

  String _toFullImageUrl(String url) {
    return url.startsWith('http') ? url : '${api.httpClient.baseUrl}$url';
  }

  /// 设置粘贴事件监听
  void _setupPasteListener() {
    setupPasteListener((filename, bytes, mimeType) {
      if (!_isAllowedImageFilename(filename)) {
        showToast('不支持的文件格式，仅支持 JPEG, PNG, GIF, WEBP', isError: true);
        return;
      }

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

  /// 设置拖拽事件监听（Web 平台）
  void _setupDropZone() {
    setupDropZone(
      onDropImage: (filename, bytes, mimeType) {
        _handleDroppedImages([(
          filename: filename,
          bytes: bytes,
          mimeType: mimeType,
        )]);
      },
      onDragStatusChanged: (isDragging) {
        setState(() {
          _isDragging = isDragging;
        });
      },
    );
  }

  /// 处理拖拽上传的图片（用于封面）
  Future<void> _handleDroppedImages(
      List<({String filename, Uint8List bytes, String mimeType})> files) async {
    if (_uploadTasks.length >= _maxCoverImages) {
      showToast('最多上传 9 张图片', isError: true);
      return;
    }

    final remaining = _maxCoverImages - _uploadTasks.length;
    final toUpload = files.take(remaining).toList();

    for (final file in toUpload) {
      if (file.bytes.length > _maxImageBytes) {
        showToast('图片 ${file.filename} 超过 15MB，已跳过', isError: true);
        continue;
      }
      _enqueueUploadTask(
        filename: file.filename,
        bytes: file.bytes,
        mimeType: file.mimeType,
      );
    }
  }

  /// 创建上传任务并立即开始压缩+上传（并行）
  void _enqueueUploadTask({
    required String filename,
    required Uint8List bytes,
    required String mimeType,
  }) {
    final task = UploadTask(
      localId: '${DateTime.now().millisecondsSinceEpoch}_${_uploadTasks.length}',
      filename: filename,
      bytes: bytes,
      mimeType: mimeType,
    );
    // 保存本地预览用的缩略图
    task.localPreviewBytes = bytes;
    _uploadTasks.add(task);

    // 异步启动，不阻塞其他任务
    _executeUploadTask(task);
  }

  /// 执行单个上传任务：压缩 → 上传
  Future<void> _executeUploadTask(UploadTask task) async {
    try {
      // 1. 压缩阶段（限流，防止多图并发压缩导致 UI 卡死）
      await _acquireCompressionSlot();
      final Uint8List compressed;
      try {
        task.status.value = UploadStatus.compressing;
        task.progress.value = 0;
        _uploadTasks.refresh();

        // 先让 UI 有机会渲染“压缩中”状态
        await Future<void>.delayed(const Duration(milliseconds: 16));

        compressed = await ImageCompressHelper.compress(
          bytes: task.bytes,
          filename: task.filename,
          mimeType: task.mimeType,
        );
      } finally {
        _releaseCompressionSlot();
      }
      task.bytes = compressed;

      // 2. 上传阶段
      task.status.value = UploadStatus.uploading;
      task.progress.value = 0;
      _uploadTasks.refresh();

      final result = await api.uploadImage(
        bytes: compressed,
        filename: task.filename,
        mimeType: task.mimeType,
        onProgress: (percent) {
          task.progress.value = percent;
        },
      );

      if (result != null) {
        final id = result['id'];
        final url = result['url'] as String?;
        if (id != null && url != null) {
          task.serverId = id.toString();
          task.serverUrl = _toFullImageUrl(url);
          task.status.value = UploadStatus.done;
          task.progress.value = 100;
          _uploadTasks.refresh();
          return;
        }
      }
      task.status.value = UploadStatus.error;
      task.errorMessage = '服务器未返回有效数据';
      _uploadTasks.refresh();
    } catch (e) {
      debugPrint('Upload task failed: $e');
      task.status.value = UploadStatus.error;
      task.errorMessage = e.toString();
      _uploadTasks.refresh();
    }
  }

  /// 重试失败的上传任务
  void _retryUploadTask(UploadTask task) {
    if (task.status.value != UploadStatus.error) return;
    task.status.value = UploadStatus.pending;
    task.errorMessage = null;
    task.progress.value = 0;
    _uploadTasks.refresh();
    _executeUploadTask(task);
  }

  /// 移除上传任务
  void _removeUploadTask(int index) {
    if (index >= 0 && index < _uploadTasks.length) {
      _uploadTasks.removeAt(index);
    }
  }

  Future<void> _acquireCompressionSlot() async {
    if (_activeCompressionCount < _maxCompressionConcurrency) {
      _activeCompressionCount++;
      return;
    }
    final waiter = Completer<void>();
    _compressionWaiters.add(waiter);
    await waiter.future;
    _activeCompressionCount++;
  }

  void _releaseCompressionSlot() {
    if (_activeCompressionCount > 0) {
      _activeCompressionCount--;
    }
    if (_compressionWaiters.isNotEmpty) {
      _compressionWaiters.removeFirst().complete();
    }
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
      // 压缩图片后再上传
      await _acquireCompressionSlot();
      final Uint8List compressed;
      try {
        // 给 UI 一个渲染帧，避免主线程长任务造成“假死感”
        await Future<void>.delayed(const Duration(milliseconds: 16));
        compressed = await ImageCompressHelper.compress(
          bytes: bytes,
          filename: filename,
          mimeType: mimeType,
        );
      } finally {
        _releaseCompressionSlot();
      }

      final result = await api.uploadImage(
        bytes: compressed,
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
      final fullUrl = _toFullImageUrl(url);

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
    if (_uploadTasks.length >= _maxCoverImages) {
      showToast('最多上传 9 张图片', isError: true);
      return;
    }

    final picker = ImagePicker();
    final files = await picker.pickMultiImage();
    if (files.isEmpty) return;

    final validFiles = files.where((file) {
      return _isAllowedImageFilename(file.name);
    }).toList();

    if (validFiles.length != files.length) {
      showToast('部分文件格式不支持，仅支持 JPEG, PNG, GIF, WEBP', isError: true);
    }

    if (validFiles.isEmpty) return;

    final remaining = _maxCoverImages - _uploadTasks.length;
    final toUpload = validFiles.take(remaining).toList();
    if (toUpload.length < validFiles.length) {
      showToast('已达上限，仅添加 ${toUpload.length} 张', isError: true);
    }

    // 并行读取所有文件字节，然后并行启动上传任务
    for (final file in toUpload) {
      try {
        final len = await file.length();
        if (len > _maxImageBytes) {
          showToast('图片 ${file.name} 超过 15MB，已跳过', isError: true);
          continue;
        }

        final Uint8List bytes;
        if (kIsWeb) {
          bytes = await file.readAsBytes();
        } else {
          bytes = await compute(_readXFileBytes, file.path);
        }
        final mimeType = file.mimeType ?? 'image/jpeg';

        _enqueueUploadTask(
          filename: file.name,
          bytes: bytes,
          mimeType: mimeType,
        );
      } catch (e) {
        debugPrint('Read file failed: $e');
        if (mounted) showToast('读取 ${file.name} 失败', isError: true);
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    if (!_isAllowedImageFilename(file.name)) {
      showToast('不支持的文件格式，仅支持 JPEG, PNG, GIF, WEBP', isError: true);
      return;
    }

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
    _pageController.dispose();
    titleController.dispose();
    _mobileBodyController.dispose();
    _quillController.dispose();
    if (kIsWeb) {
      removePasteListener();
      removeDropZone();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // 设置 Web 平台剪贴板粘贴监听
    if (kIsWeb) {
      _setupPasteListener();
      _setupDropZone();
    }

    if (widget.discussion != null) {
      titleController.text = widget.discussion!.title;
      _mobileBodyController.text = widget.discussion!.rawBodyText;
      // Convert raw markdown to Delta for Quill
      try {
        final mdDocument = md.Document(
          encodeHtml: false,
          extensionSet: md.ExtensionSet.gitHubWeb,
        );
        final mdToDelta = MarkdownToDelta(markdownDocument: mdDocument);
        final delta = mdToDelta.convert(widget.discussion!.rawBodyText);
        _quillController.document = quill.Document.fromDelta(delta);
      } catch (e) {
        debugPrint('Markdown parsing failed: $e');
        _quillController.document.insert(0, widget.discussion!.rawBodyText);
      }

      // Load existing covers as already-done upload tasks
      for (final cover in widget.discussion!.coverImages) {
        final task = UploadTask(
          localId: 'existing_${_uploadTasks.length}',
          filename: '',
          bytes: Uint8List(0),
          mimeType: 'image/jpeg',
        );
        task.serverId = '';
        task.serverUrl = cover.url;
        task.status.value = UploadStatus.done;
        task.progress.value = 100;
        _uploadTasks.add(task);
      }
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

  Future<void> _submit({bool isMobile = false}) async {
    final title = titleController.text.trim();
    final String markdownText;
    if (isMobile) {
      markdownText = _mobileBodyController.text.trim();
    } else {
      final delta = _quillController.document.toDelta();
      markdownText = normalizeMarkdown(DeltaToMarkdown().convert(delta));
    }

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
      showToast('标题不能为空', isError: true);
      return;
    }
    // Block submission while images are still uploading
    if (_isCoverUploading) {
      showToast('图片正在上传中，请稍候', isError: true);
      return;
    }
    // Content check: either text or images must exist
    if (markdownText.isEmpty && _uploadedImages.isEmpty) {
      showToast('内容不能为空', isError: true);
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      Response<Map<String, dynamic>> res;

      if (widget.discussion != null) {
        // Edit Mode
        res = await api.updateDiscussion(
          id: widget.discussion!.id,
          title: title,
          text: markdownText,
          coverId: finalCoverId,
        );
      } else {
        // Create Mode
        var slug = _slugify(title);
        final user = c.user.value;
        final authorId = c.authorId.value ?? await c.ensureAuthorForUser(user);
        if (authorId == null || authorId.isEmpty) {
          throw Exception('无法关联作者，请重新登录后再试');
        }

        final captchaService = Get.find<CaptchaService>();
        Future<Response<Map<String, dynamic>>> submitArticle({
          CaptchaPayload? captcha,
        }) {
          return api.createArticle(
            title: title,
            text: markdownText,
            slug: slug,
            coverId: finalCoverId,
            authorId: authorId,
            captcha: captcha,
          );
        }

        res = await submitArticle();

        // Check for error in REST format (error object) or GraphQL format (errors list)
        final resBody = res.body;
        if (resBody != null) {
          final error = resBody['error'];
          final errors = resBody['errors'];
          if ((error != null || errors != null) &&
              _isSlugUniqueError(resBody)) {
            slug = _slugifyUnique(title);
            res = await submitArticle();
          }
        }

        if (res.hasError &&
            CaptchaService.isCaptchaRequiredResponse(
              res.body,
              expectedScene: CaptchaScene.articleCreate,
            )) {
          final captcha = await captchaService.verifyForRequiredResponse(
            fallbackScene: CaptchaScene.articleCreate,
            body: res.body,
          );
          res = await submitArticle(captcha: captcha);

          final retryBody = res.body;
          if (retryBody != null) {
            final error = retryBody['error'];
            final errors = retryBody['errors'];
            if ((error != null || errors != null) &&
                _isSlugUniqueError(retryBody)) {
              slug = _slugifyUnique(title);
              res = await submitArticle(captcha: captcha);
            }
          }
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
            msg = CaptchaService.resolveErrorMessageFromBody(errorBody) ??
                error['message']?.toString();
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

      if (widget.discussion != null) {
        widget.discussion!.title = title;
        widget.discussion!.rawBodyText = markdownText;
        widget.discussion!.bodyHTML = md.markdownToHtml(
          markdownText,
          extensionSet: md.ExtensionSet.gitHubWeb,
        );
      }

      Get.back(result: true);
      showToast(widget.discussion != null ? '修改成功' : '发帖成功');
      // Refresh list
      c.refreshSearchData();
    } catch (e) {
      showToast('发帖失败: $e', isError: true);
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
    final screenW = MediaQuery.of(context).size.width;
    final isWindowed = screenW >= 800;
    final isDesktop = screenW >= 600;

    final double baseFactor = isWindowed ? 0.7 : 1.0;
    final double zoomScale = isWindowed ? 1.1 : 1.0;
    final double layoutFactor = baseFactor * zoomScale;

    // Mobile uses a simple TextField editor; desktop uses the Quill PageView
    final mobileEditor = CreateDiscussionEditorPage(
      titleController: titleController,
      quillController: _quillController,
      onPickAndUploadImage: _pickAndUploadImage,
      isMobile: true,
      mobileBodyController: _mobileBodyController,
      mobileUploadTasks: _uploadTasks,
      onRemoveMobileImage: _removeUploadTask,
      onRetryMobileImage: _retryUploadTask,
    );

    final content = PageView(
      scrollDirection: isDesktop ? Axis.vertical : Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      controller: _pageController,
      onPageChanged: (index) {
        setState(() {
          _selectedIndex = index;
        });
      },
      children: [
        CreateDiscussionEditorPage(
          titleController: titleController,
          quillController: _quillController,
          onPickAndUploadImage: _pickAndUploadImage,
        ),
        CreateDiscussionCoverPage(
          uploadTasks: _uploadTasks,
          isDragging: _isDragging,
          onPickImages: _pickImages,
          onRemoveImageAt: _removeUploadTask,
          onRetryAt: _retryUploadTask,
          onDroppedImages: _handleDroppedImages,
          onDraggingChanged: (isDragging) {
            setState(() {
              _isDragging = isDragging;
            });
          },
        ),
      ],
    );

    final scaffold = Scaffold(
      backgroundColor: const Color(0xff121212),
      bottomNavigationBar: isDesktop
          ? null
          : Obx(() => CreateDiscussionMobileNav(
                isLoading: isLoading,
                onPickImage: _pickImages,
                onSubmit: () => _submit(isMobile: true),
                imageCount: _uploadTasks.length,
                uploadingCount: _uploadTasks
                    .where((t) =>
                        t.status.value == UploadStatus.uploading ||
                        t.status.value == UploadStatus.compressing ||
                        t.status.value == UploadStatus.pending)
                    .length,
              )),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            CreateDiscussionHeader(
              controller: c,
              title: '发布委托',
              onClose: () => Get.back(),
            ),
            // Body
            Expanded(
              child: isDesktop
                  ? Row(
                      children: [
                        CreateDiscussionDesktopSidebar(
                          selectedIndex: _selectedIndex,
                          onSelectPage: (index) => _pageController.jumpToPage(index),
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
                              CreateDiscussionDesktopFooter(
                                isLoading: isLoading,
                                onSubmit: _submit,
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : mobileEditor,
            ),
          ],
        ),
      ),
    );

    return SafeArea(
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final safeW = constraints.maxWidth;
            final safeH = constraints.maxHeight;
            return SizedBox(
              width: safeW * layoutFactor,
              height: safeH * layoutFactor,
              child: FittedBox(
                child: SizedBox(
                  width: safeW * baseFactor,
                  height: safeH * baseFactor,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(59, 255, 255, 255),
                      borderRadius: isWindowed
                          ? const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            )
                          : BorderRadius.zero,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: isWindowed
                            ? const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              )
                            : BorderRadius.zero,
                      ),
                      child: ClipRRect(
                        borderRadius: isWindowed
                            ? const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              )
                            : BorderRadius.zero,
                        child: scaffold,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Top-level function required by compute() — reads file bytes in a background isolate.
/// Only called on non-Web platforms where dart:io File is available.
Future<Uint8List> _readXFileBytes(String path) => File(path).readAsBytes();
