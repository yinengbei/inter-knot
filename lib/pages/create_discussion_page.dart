import 'dart:async';
import 'dart:collection';
import 'dart:convert';
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
import 'package:inter_knot/helpers/throttle.dart';
import 'package:inter_knot/helpers/toast.dart';
import 'package:inter_knot/helpers/upload_task.dart';
import 'package:inter_knot/helpers/web_hooks.dart';
import 'package:inter_knot/models/captcha.dart';
import 'package:inter_knot/models/h_data.dart';
import 'package:markdown_quill/markdown_quill.dart';

import 'package:inter_knot/pages/create_discussion/create_discussion_desktop_footer.dart';
import 'package:inter_knot/pages/create_discussion/create_discussion_desktop_sidebar.dart';
import 'package:inter_knot/pages/create_discussion/create_discussion_cover_page.dart';
import 'package:inter_knot/pages/create_discussion/create_discussion_drafts_page.dart';
import 'package:inter_knot/pages/create_discussion/create_discussion_editor_page.dart';
import 'package:inter_knot/pages/create_discussion/create_discussion_header.dart';
import 'package:inter_knot/pages/create_discussion/create_discussion_mobile_nav.dart';
import 'package:inter_knot/pages/create_discussion/create_discussion_post_settings_sheet.dart';

import 'package:inter_knot/models/discussion.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:inter_knot/services/captcha_service.dart';

class CreateDiscussionPage extends StatefulWidget {
  const CreateDiscussionPage({
    super.key,
    this.discussion,
    this.documentId,
  });

  final DiscussionModel? discussion;
  final String? documentId;

  static Future<bool?> show(BuildContext context,
      {DiscussionModel? discussion, String? documentId}) {
    return showZZZDialog<bool>(
      context: context,
      pageBuilder: (context) {
        return CreateDiscussionPage(
          discussion: discussion,
          documentId: documentId,
        );
      },
    );
  }

  @override
  State<CreateDiscussionPage> createState() => _CreateDiscussionPageState();
}

class _CreateDiscussionPageState extends State<CreateDiscussionPage> {
  static const _maxCoverImages = 9;
  static const _maxImageBytes = 30 * 1024 * 1024; // 30MB
  static const _allowedImageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];

  final PageController _pageController = PageController();
  final titleController = TextEditingController();
  final _mobileBodyController = TextEditingController();
  final _quillController = quill.QuillController.basic();

  // Images State — each image is tracked as an UploadTask with its own status/progress
  final RxList<UploadTask> _uploadTasks = <UploadTask>[].obs;
  bool _compressBeforeUpload = true;
  bool _isDragging = false; // 拖拽状态
  Timer? _autoSaveDebounce;
  Future<void>? _saveDraftFuture;
  bool _isInitializingDraft = false;
  bool _isSavingDraft = false;
  bool _isPublishing = false;
  bool _isDeletingDraft = false;
  bool _hasUnsavedChanges = false;
  bool _suppressChangeTracking = false;
  bool _isDesktopEditorActive = true;
  late final bool _draftFeaturesEnabled;
  String? _documentId;
  String _lastSavedSnapshot = '';
  List<dynamic>? _persistedEditorState;
  String _persistedBodyText = '';
  DiscussionModel? _activeDiscussion;
  final RxSet<HDataModel> _draftEntries = <HDataModel>{}.obs;
  final RxBool _draftHasNextPage = true.obs;
  String? _draftEndCursor;
  bool _isDraftListLoading = false;
  bool _draftListInitialized = false;

  // 压缩是 CPU 密集型任务：限制并发，避免 UI 卡顿（Web 单线程更明显）
  final Queue<Completer<void>> _compressionWaiters = Queue<Completer<void>>();
  int _activeCompressionCount = 0;

  int get _maxCompressionConcurrency => kIsWeb ? 1 : 2;

  /// 已成功上传的图片（便捷 getter）
  List<({String id, String url})> get _uploadedImages => _uploadTasks
      .where((t) =>
          t.status.value == UploadStatus.done &&
          t.serverId != null &&
          t.serverId!.isNotEmpty &&
          t.serverUrl != null)
      .map((t) => (id: t.serverId!, url: t.serverUrl!))
      .toList();

  /// 是否有任何图片正在上传/压缩中
  bool get _isCoverUploading => _uploadTasks.any((t) =>
      t.status.value == UploadStatus.uploading ||
      t.status.value == UploadStatus.compressing ||
      t.status.value == UploadStatus.pending);

  int _selectedIndex = 0;

  final c = Get.find<Controller>();
  late final api = Get.find<Api>();
  late final _fetchMoreDraftEntries = retryThrottle(
    _loadMoreDraftEntries,
    const Duration(milliseconds: 500),
  );

  bool get _hasAnyDraftContent {
    final title = titleController.text.trim();
    final body = _currentBodyText.trim();
    return title.isNotEmpty || body.isNotEmpty || _uploadedImages.isNotEmpty;
  }

  bool get _canPublish =>
      !_isInitializingDraft &&
      !_isSavingDraft &&
      !_isPublishing &&
      !_isDeletingDraft &&
      !_isCoverUploading &&
      titleController.text.trim().isNotEmpty &&
      (_currentBodyText.trim().isNotEmpty || _uploadedImages.isNotEmpty);

  bool get _supportsDeleteCurrentDraft =>
      _draftFeaturesEnabled &&
      _documentId != null &&
      _documentId!.isNotEmpty &&
      (_activeDiscussion?.hasPublishedVersion != true);

  String get _currentBodyText {
    if (_isDesktopEditorActive) {
      return _quillController.document.toPlainText().trimRight();
    }
    return _mobileBodyController.text.trim();
  }

  List<dynamic>? get _currentEditorState {
    if (_isDesktopEditorActive) {
      return _quillController.document.toDelta().toJson();
    }

    final mobileText = _mobileBodyController.text.trim();
    if (mobileText == _persistedBodyText && _persistedEditorState != null) {
      return List<dynamic>.from(_persistedEditorState!);
    }
    return null;
  }

  dynamic get _currentCoverPayload {
    if (_uploadedImages.isEmpty) {
      return <String>[];
    }
    if (_uploadedImages.length == 1) {
      return _uploadedImages.first.id;
    }
    return _uploadedImages.map((e) => e.id).toList();
  }

  Map<String, dynamic> _buildDraftPayload() {
    return <String, dynamic>{
      'title': titleController.text.trim(),
      'text': _currentBodyText,
      'editorState': _currentEditorState,
      'cover': _currentCoverPayload,
    };
  }

  String _draftSnapshot(Map<String, dynamic> payload) {
    return jsonEncode(payload);
  }

  void _syncSavedSnapshot() {
    final payload = _buildDraftPayload();
    _lastSavedSnapshot = _draftSnapshot(payload);
    _persistedBodyText = payload['text']?.toString() ?? '';
    final editorState = payload['editorState'];
    _persistedEditorState =
        editorState is List ? List<dynamic>.from(editorState) : null;
    _hasUnsavedChanges = false;
  }

  void _scheduleAutoSave() {
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = Timer(const Duration(milliseconds: 600), () {
      unawaited(_saveDraft());
    });
  }

  void _markDraftDirty({bool scheduleSave = true}) {
    if (!_draftFeaturesEnabled) {
      return;
    }

    if (_suppressChangeTracking) {
      return;
    }

    _hasUnsavedChanges = true;

    if (_isInitializingDraft) {
      if (mounted) {
        setState(() {});
      }
      return;
    }

    if (_documentId == null && !_hasAnyDraftContent) {
      if (mounted) {
        setState(() {});
      }
      return;
    }

    if (scheduleSave) {
      _scheduleAutoSave();
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _handleTitleChanged() => _markDraftDirty();

  void _handleMobileBodyChanged() {
    if (!_isDesktopEditorActive) {
      _markDraftDirty();
    }
  }

  void _handleQuillChanged() {
    if (_isDesktopEditorActive) {
      _markDraftDirty();
    }
  }

  bool _isAllowedImageFilename(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return _allowedImageExtensions.contains(ext);
  }

  String _toFullImageUrl(String url) {
    return url.startsWith('http') ? url : '${api.httpClient.baseUrl}$url';
  }

  Future<String?> _ensureAuthorId() async {
    final user = c.user.value;
    final authorId = c.authorId.value ?? user?.authorId;
    if (authorId != null && authorId.isNotEmpty) {
      return authorId;
    }
    return c.ensureAuthorForUser(user);
  }

  String _extractResponseMessage(Response<Map<String, dynamic>> res) {
    final body = res.body;
    if (body != null) {
      final resolved = CaptchaService.resolveErrorMessageFromBody(body);
      if (resolved != null && resolved.isNotEmpty) {
        return resolved;
      }

      final error = body['error'];
      if (error is Map) {
        final message = error['message']?.toString();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }

      final errors = body['errors'];
      if (errors is List && errors.isNotEmpty) {
        final first = errors.first;
        if (first is Map) {
          final message = first['message']?.toString();
          if (message != null && message.isNotEmpty) {
            return message;
          }
        }
      }
    }

    return res.statusText ?? 'Unknown error';
  }

  void _setCurrentDiscussion(DiscussionModel? discussion) {
    _activeDiscussion = discussion;
    if (discussion != null && discussion.id.isNotEmpty) {
      _documentId = discussion.id;
    }
  }

  Future<void> _ensureDraftEntriesLoaded() async {
    if (!_draftFeaturesEnabled) {
      return;
    }
    if (_draftListInitialized || _isDraftListLoading) {
      return;
    }
    await _refreshDraftEntries(silent: true);
  }

  Future<void> _refreshDraftEntries({bool silent = false}) async {
    if (!_draftFeaturesEnabled) {
      return;
    }
    _draftEntries.clear();
    _draftEndCursor = null;
    _draftHasNextPage.value = true;
    _draftListInitialized = true;
    await _loadMoreDraftEntries(silent: silent);
  }

  Future<void> _loadMoreDraftEntries({bool silent = false}) async {
    if (!_draftFeaturesEnabled) {
      return;
    }
    if (_isDraftListLoading || !_draftHasNextPage.value) {
      return;
    }
    if (!c.isLogin.value) {
      _draftHasNextPage.value = false;
      _draftListInitialized = true;
      if (mounted) {
        setState(() {});
      }
      return;
    }

    _isDraftListLoading = true;
    if (mounted) {
      setState(() {});
    }

    try {
      final res = await api.getMyDraftDiscussions(_draftEndCursor ?? '');
      _draftEntries.addAll(res.nodes);
      _draftEndCursor = res.endCursor;
      _draftHasNextPage.value = res.hasNextPage;
    } catch (e) {
      if (!silent && mounted) {
        showToast('加载草稿失败: $e', isError: true);
      }
    } finally {
      _isDraftListLoading = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _selectDesktopPage(int index) {
    if (!_draftFeaturesEnabled && index > 1) {
      return;
    }
    if (index == 2) {
      unawaited(_ensureDraftEntriesLoaded());
    }
    _pageController.jumpToPage(index);
  }

  Future<void> _openDraftFromList(
    BuildContext _context,
    HDataModel item,
    DiscussionModel _discussion,
  ) async {
    if (_documentId == item.id) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      return;
    }

    if (_hasUnsavedChanges && (_documentId != null || _hasAnyDraftContent)) {
      try {
        await _saveDraft(force: true);
      } catch (e) {
        if (mounted) {
          showToast('当前草稿保存失败: $e', isError: true);
        }
        return;
      }
    }

    if (mounted) {
      setState(() {
        _isInitializingDraft = true;
      });
    }

    try {
      final nextDiscussion = await api.getMyDraftDetail(item.id);
      _applyDiscussionToEditor(nextDiscussion);
      if (mounted && _pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    } catch (e) {
      if (mounted) {
        showToast('加载草稿失败: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializingDraft = false;
        });
      }
    }
  }

  Future<void> _showMobileDraftsPage() async {
    if (!_draftFeaturesEnabled || !mounted) {
      return;
    }

    unawaited(_ensureDraftEntriesLoaded());

    await showZZZDialog<void>(
      context: context,
      showBackgroundEffect: false,
      pageBuilder: (dialogContext) {
        return Scaffold(
          backgroundColor: const Color(0xff121212),
          body: SafeArea(
            child: Column(
              children: [
                CreateDiscussionHeader(
                  controller: c,
                  title: '草稿箱',
                  onClose: () => Navigator.of(dialogContext).pop(),
                ),
                Expanded(
                  child: Obx(
                    () => CreateDiscussionDraftsPage(
                      isLoggedIn: c.isLogin.value,
                      isLoading: _isDraftListLoading,
                      drafts: _draftEntries,
                      hasNextPage: _draftHasNextPage.value,
                      onFetchMore: _fetchMoreDraftEntries,
                      onOpenDraft: (context, item, discussion) async {
                        final previousDocumentId = _documentId;
                        await _openDraftFromList(context, item, discussion);
                        final openedSelectedDraft = _documentId == item.id ||
                            previousDocumentId == item.id;
                        if (openedSelectedDraft && dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
        _handleDroppedImages([
          (
            filename: filename,
            bytes: bytes,
            mimeType: mimeType,
          )
        ]);
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
        showToast('图片 ${file.filename} 超过 30MB，已跳过', isError: true);
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
      localId:
          '${DateTime.now().millisecondsSinceEpoch}_${_uploadTasks.length}',
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
      Uint8List uploadBytes = task.bytes;

      // 1. 压缩阶段（限流，防止多图并发压缩导致 UI 卡顿）
      if (_compressBeforeUpload) {
        await _acquireCompressionSlot();
        try {
          task.status.value = UploadStatus.compressing;
          task.progress.value = 0;
          _uploadTasks.refresh();

          // 先让 UI 有机会渲染“压缩中”状态
          await Future<void>.delayed(const Duration(milliseconds: 16));

          uploadBytes = await ImageCompressHelper.compress(
            bytes: task.bytes,
            filename: task.filename,
            mimeType: task.mimeType,
          );
        } finally {
          _releaseCompressionSlot();
        }
      }

      task.bytes = uploadBytes;

      // 2. 上传阶段
      task.status.value = UploadStatus.uploading;
      task.progress.value = 0;
      _uploadTasks.refresh();

      final result = await api.uploadImage(
        bytes: uploadBytes,
        filename: task.filename,
        mimeType: task.mimeType,
        onProgress: (percent) {
          task.progress.value = percent;
        },
      );

      if (result != null) {
        final id = result['documentId'] ?? result['id'];
        final url = result['url'] as String?;
        if (id != null && url != null) {
          task.serverId = id.toString();
          task.serverUrl = _toFullImageUrl(url);
          task.status.value = UploadStatus.done;
          task.progress.value = 100;
          _uploadTasks.refresh();
          _markDraftDirty();
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
      _markDraftDirty();
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
      Uint8List uploadBytes = bytes;
      if (_compressBeforeUpload) {
        // 压缩图片后再上传
        await _acquireCompressionSlot();
        try {
          // 给 UI 一个渲染帧，避免主线程长任务造成“假死感”
          await Future<void>.delayed(const Duration(milliseconds: 16));
          uploadBytes = await ImageCompressHelper.compress(
            bytes: bytes,
            filename: filename,
            mimeType: mimeType,
          );
        } finally {
          _releaseCompressionSlot();
        }
      }

      final result = await api.uploadImage(
        bytes: uploadBytes,
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
          showToast('图片 ${file.name} 超过 30MB，已跳过', isError: true);
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

  Future<void> _saveDraft({bool force = false}) async {
    if (!_draftFeaturesEnabled && !force) {
      return;
    }

    final inFlight = _saveDraftFuture;
    if (inFlight != null) {
      await inFlight;
      if (!force) {
        return;
      }
    }

    final next = _performSaveDraft(force: force);
    _saveDraftFuture = next;
    try {
      await next;
    } finally {
      if (identical(_saveDraftFuture, next)) {
        _saveDraftFuture = null;
      }
    }
  }

  Future<void> _performSaveDraft({bool force = false}) async {
    if (!_draftFeaturesEnabled && !force) {
      return;
    }

    if (_isInitializingDraft) {
      return;
    }

    if (_documentId == null && !_hasAnyDraftContent) {
      return;
    }

    final previousDocumentId = _documentId;
    final payload = _buildDraftPayload();
    final snapshot = _draftSnapshot(payload);
    if (!force && snapshot == _lastSavedSnapshot) {
      return;
    }

    final authorId = await _ensureAuthorId();
    if (authorId == null || authorId.isEmpty) {
      throw Exception('无法关联作者，请重新登录后再试');
    }

    if (_draftFeaturesEnabled && mounted) {
      setState(() {
        _isSavingDraft = true;
      });
    }

    try {
      late final Response<Map<String, dynamic>> res;
      if (_documentId == null) {
        res = await api.createArticleDraft(
          title: payload['title']?.toString() ?? '',
          text: payload['text']?.toString() ?? '',
          editorState: payload['editorState'] as List<dynamic>?,
          coverId: payload['cover'],
          authorId: authorId,
        );
      } else {
        res = await api.updateArticleDraft(
          id: _documentId!,
          title: payload['title']?.toString() ?? '',
          text: payload['text']?.toString() ?? '',
          editorState: payload['editorState'] as List<dynamic>?,
          coverId: payload['cover'],
          authorId: authorId,
        );
      }

      if (res.hasError) {
        throw Exception(_extractResponseMessage(res));
      }

      final saved = api.unwrapData<Map<String, dynamic>>(res);
      final discussion = DiscussionModel.fromJson(
        saved,
        isEditableDraft: true,
      );

      final currentDiscussion = _activeDiscussion;
      _documentId = discussion.id.isNotEmpty
          ? discussion.id
          : (saved['documentId']?.toString() ?? _documentId);
      _syncSavedSnapshot();

      if (currentDiscussion != null) {
        currentDiscussion.updateFrom(discussion);
        currentDiscussion.id = _documentId ?? currentDiscussion.id;
        _activeDiscussion = currentDiscussion;
      } else {
        _activeDiscussion = discussion;
      }

      if (_activeDiscussion != null) {
        HDataModel.upsertCachedDiscussion(_activeDiscussion!);
      }

      if (_draftFeaturesEnabled &&
          (_selectedIndex == 2 || previousDocumentId == null)) {
        unawaited(_refreshDraftEntries(silent: true));
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      _hasUnsavedChanges = true;
      rethrow;
    } finally {
      if (_draftFeaturesEnabled && mounted) {
        setState(() {
          _isSavingDraft = false;
        });
      }
    }
  }

  void _applyDiscussionToEditor(DiscussionModel discussion) {
    _suppressChangeTracking = true;
    try {
      _setCurrentDiscussion(discussion);
      titleController.text = discussion.title;
      _mobileBodyController.text = discussion.rawBodyText;

      try {
        final editorState = discussion.editorState;
        if (editorState != null && editorState.isNotEmpty) {
          _quillController.document = quill.Document.fromJson(editorState);
        } else {
          final mdDocument = md.Document(
            encodeHtml: false,
            extensionSet: md.ExtensionSet.gitHubWeb,
          );
          final mdToDelta = MarkdownToDelta(markdownDocument: mdDocument);
          final delta = mdToDelta.convert(discussion.rawBodyText);
          _quillController.document = quill.Document.fromDelta(delta);
        }
      } catch (e) {
        debugPrint('Markdown parsing failed: $e');
        _quillController.document = quill.Document()
          ..insert(0, discussion.rawBodyText);
      }

      _uploadTasks.clear();
      for (final cover in discussion.coverImages) {
        final task = UploadTask(
          localId: 'existing_${_uploadTasks.length}',
          filename: '',
          bytes: Uint8List(0),
          mimeType: 'image/jpeg',
        );
        task.serverId = cover.id ?? '';
        task.serverUrl = cover.url;
        task.status.value = UploadStatus.done;
        task.progress.value = 100;
        _uploadTasks.add(task);
      }

      _documentId = discussion.id.isNotEmpty ? discussion.id : _documentId;
      _persistedBodyText = discussion.rawBodyText;
      _persistedEditorState = discussion.editorState == null
          ? null
          : List<dynamic>.from(discussion.editorState!);
      _syncSavedSnapshot();
    } finally {
      _suppressChangeTracking = false;
    }
  }

  Future<void> _loadDraftIfNeeded() async {
    if (!_draftFeaturesEnabled) {
      return;
    }

    final shouldLoadDraft =
        widget.documentId != null && widget.documentId!.isNotEmpty
            ? widget.discussion == null || widget.discussion!.isEditableDraft
            : (_activeDiscussion?.isEditableDraft ?? false);
    if (!shouldLoadDraft) {
      return;
    }

    final draftId = widget.documentId ?? _activeDiscussion?.id;
    if (draftId == null || draftId.isEmpty) {
      return;
    }

    if (mounted) {
      setState(() {
        _isInitializingDraft = true;
      });
    }

    try {
      final loadedDiscussion = await api.getMyDraftDetail(draftId);
      if (widget.discussion != null && widget.discussion!.id == draftId) {
        widget.discussion!.updateFrom(loadedDiscussion);
        widget.discussion!.id = loadedDiscussion.id;
        _applyDiscussionToEditor(widget.discussion!);
      } else {
        _applyDiscussionToEditor(loadedDiscussion);
      }
    } catch (e) {
      debugPrint('Load draft failed: $e');
      if (_activeDiscussion == null && mounted) {
        showToast('加载草稿失败: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializingDraft = false;
        });
      }
    }
  }

  Future<void> _handleClose() async {
    _autoSaveDebounce?.cancel();

    if (_draftFeaturesEnabled &&
        _hasUnsavedChanges &&
        (_documentId != null || _hasAnyDraftContent)) {
      try {
        await _saveDraft(force: true);
      } catch (_) {}
    }

    if (mounted) {
      Get.back();
    }
  }

  Future<void> _deleteCurrentDraft() async {
    final documentId = _documentId;
    if (documentId == null ||
        documentId.isEmpty ||
        !_supportsDeleteCurrentDraft) {
      return;
    }

    final confirmed = await showDeleteConfirmDialog(
      context: context,
      title: '确认删除草稿',
      message: '确定要删除这个草稿吗？此操作不可恢复。',
      width: 300,
    );

    if (confirmed != true) {
      return;
    }

    if (mounted) {
      setState(() {
        _isDeletingDraft = true;
      });
    }

    try {
      final res = await api.deleteDiscussion(documentId);
      if (res.hasError) {
        throw Exception(_extractResponseMessage(res));
      }

      _autoSaveDebounce?.cancel();
      await _refreshDraftEntries(silent: true);

      if (!mounted) {
        return;
      }

      Get.back(result: true);
      showToast('草稿已删除');
    } catch (e) {
      if (mounted) {
        showToast('删除草稿失败: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingDraft = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _autoSaveDebounce?.cancel();
    titleController.removeListener(_handleTitleChanged);
    _mobileBodyController.removeListener(_handleMobileBodyChanged);
    _quillController.removeListener(_handleQuillChanged);
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
    _draftFeaturesEnabled =
        widget.discussion == null || widget.discussion!.isEditableDraft;
    _activeDiscussion = widget.discussion;
    _documentId = widget.documentId ?? _activeDiscussion?.id;
    titleController.addListener(_handleTitleChanged);
    _mobileBodyController.addListener(_handleMobileBodyChanged);
    _quillController.addListener(_handleQuillChanged);

    // 设置 Web 平台剪贴板粘贴监听
    if (kIsWeb) {
      _setupPasteListener();
      _setupDropZone();
    }

    if (_activeDiscussion != null) {
      _applyDiscussionToEditor(_activeDiscussion!);
    }
    unawaited(_loadDraftIfNeeded());
  }

  Future<void> _publish({bool isMobile = false}) async {
    _isDesktopEditorActive = !isMobile;

    final title = titleController.text.trim();
    final textValue = _currentBodyText.trim();

    if (title.isEmpty) {
      showToast('标题不能为空', isError: true);
      return;
    }
    if (_isCoverUploading) {
      showToast('图片正在上传中，请稍候', isError: true);
      return;
    }
    if (textValue.isEmpty && _uploadedImages.isEmpty) {
      showToast('内容不能为空', isError: true);
      return;
    }

    if (mounted) {
      setState(() {
        _isPublishing = true;
      });
    }

    try {
      await _saveDraft(force: true);

      final documentId = _documentId;
      if (documentId == null || documentId.isEmpty) {
        throw Exception('草稿保存成功后仍缺少 documentId');
      }

      final captchaService = Get.find<CaptchaService>();
      CaptchaPayload? captcha = await captchaService.verifyForArticlePublish();

      var res = await api.publishArticleDraft(
        id: documentId,
        captcha: captcha,
      );

      if (res.hasError &&
          CaptchaService.isCaptchaRequiredResponse(
            res.body,
            expectedScene: CaptchaScene.articlePublish,
          )) {
        captcha = await captchaService.verifyForRequiredResponse(
          fallbackScene: CaptchaScene.articlePublish,
          body: res.body,
        );
        res = await api.publishArticleDraft(
          id: documentId,
          captcha: captcha,
        );
      }

      if (res.hasError) {
        throw Exception(_extractResponseMessage(res));
      }

      final publishedData = api.unwrapData<Map<String, dynamic>>(res);
      final publishedDiscussion = DiscussionModel.fromJson(publishedData);
      _syncSavedSnapshot();

      if (_activeDiscussion != null) {
        _activeDiscussion!.updateFrom(publishedDiscussion);
        _activeDiscussion!
          ..hasPublishedVersion = true
          ..isEditableDraft = false;
      } else {
        _activeDiscussion = publishedDiscussion
          ..hasPublishedVersion = true
          ..isEditableDraft = false;
      }

      Get.back(result: true);
      showToast('发布成功');
      c.refreshSearchData();
    } catch (e) {
      showToast('发布失败: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isPublishing = false;
        });
      }
    }
  }

  Future<void> _showMobilePostSettingsSheet() {
    return showCreateDiscussionPostSettingsSheet(
      context: context,
      compressBeforeUpload: _compressBeforeUpload,
      onCompressionChanged: (value) {
        setState(() {
          _compressBeforeUpload = value;
        });
      },
      showDeleteDraft: _supportsDeleteCurrentDraft,
      onDeleteDraft: _supportsDeleteCurrentDraft ? _deleteCurrentDraft : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isWindowed = screenW >= 800;
    final isDesktop = screenW >= 600;

    // Keep autosave/publish reading from the editor that is actually visible.
    _isDesktopEditorActive = isDesktop;

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
      onPickCoverImages: _pickImages,
      onOpenPostSettings: _showMobilePostSettingsSheet,
      mobileCompressBeforeUpload: _compressBeforeUpload,
      mobileMaxCoverImages: _maxCoverImages,
    );

    final draftsPage = Obx(
      () => CreateDiscussionDraftsPage(
        isLoggedIn: c.isLogin.value,
        isLoading: _isDraftListLoading,
        drafts: _draftEntries,
        hasNextPage: _draftHasNextPage.value,
        onFetchMore: _fetchMoreDraftEntries,
        onOpenDraft: _openDraftFromList,
      ),
    );

    final contentPages = <Widget>[
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
      if (_draftFeaturesEnabled) draftsPage,
    ];

    final content = PageView(
      scrollDirection: isDesktop ? Axis.vertical : Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      controller: _pageController,
      onPageChanged: (index) {
        if (_draftFeaturesEnabled && index == 2) {
          unawaited(_ensureDraftEntriesLoaded());
        }
        setState(() {
          _selectedIndex = index;
        });
      },
      children: contentPages,
    );

    final scaffold = Scaffold(
      backgroundColor: const Color(0xff121212),
      bottomNavigationBar: isDesktop
          ? null
          : AnimatedBuilder(
              animation: Listenable.merge([
                titleController,
                _mobileBodyController,
              ]),
              builder: (context, _) => Obx(
                () => CreateDiscussionMobileNav(
                  isSavingDraft: _isSavingDraft,
                  isPublishing: _isPublishing,
                  submitEnabled: _canPublish,
                  onOpenDrafts: _showMobileDraftsPage,
                  onSubmit: () => _publish(isMobile: true),
                  draftCount: _draftEntries.length,
                  showDraftButton: _draftFeaturesEnabled,
                ),
              ),
            ),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            CreateDiscussionHeader(
              controller: c,
              title: '发布委托',
              onClose: _handleClose,
            ),
            // Body
            Expanded(
              child: isDesktop
                  ? Row(
                      children: [
                        CreateDiscussionDesktopSidebar(
                          selectedIndex: _selectedIndex,
                          onSelectPage: _selectDesktopPage,
                          showDrafts: _draftFeaturesEnabled,
                        ),
                        Expanded(
                          flex: 9,
                          child: Column(
                            children: [
                              Expanded(
                                child: Container(
                                  margin: EdgeInsets.only(
                                    top: 16,
                                    left: 8,
                                    right: 16,
                                    bottom: _selectedIndex == 2 ? 16 : 8,
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
                              if (_selectedIndex != 2)
                                CreateDiscussionDesktopFooter(
                                  isSavingDraft: _isSavingDraft,
                                  isPublishing: _isPublishing,
                                  isDeletingDraft: _isDeletingDraft,
                                  onSubmit: () => _publish(),
                                  submitEnabled: _canPublish,
                                  showCompressionToggle: _selectedIndex == 1,
                                  compressBeforeUpload: _compressBeforeUpload,
                                  onCompressionChanged: (value) {
                                    setState(() {
                                      _compressBeforeUpload = value;
                                    });
                                  },
                                  showDeleteButton: _selectedIndex != 2 &&
                                      _supportsDeleteCurrentDraft,
                                  onDeleteDraft: _deleteCurrentDraft,
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
