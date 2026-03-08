import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/image_viewer.dart';
import 'package:inter_knot/helpers/upload_task.dart';
import 'package:url_launcher/url_launcher_string.dart';

class CreateDiscussionEditorPage extends StatelessWidget {
  const CreateDiscussionEditorPage({
    super.key,
    required this.titleController,
    required this.quillController,
    required this.onPickAndUploadImage,
    this.isMobile = false,
    this.mobileBodyController,
    this.mobileUploadTasks,
    this.onRemoveMobileImage,
    this.onRetryMobileImage,
  });

  final TextEditingController titleController;
  final quill.QuillController quillController;
  final VoidCallback onPickAndUploadImage;

  // Mobile-only
  final bool isMobile;
  final TextEditingController? mobileBodyController;
  final RxList<UploadTask>? mobileUploadTasks;
  final void Function(int index)? onRemoveMobileImage;
  final void Function(UploadTask task)? onRetryMobileImage;

  bool _isCtrlPressed() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight);
  }

  Future<void> _handleLaunchUrl(String url) async {
    if (!_isCtrlPressed()) return;
    await launchUrlString(url);
  }

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return _MobileEditorBody(
        titleController: titleController,
        bodyController: mobileBodyController!,
        uploadTasks: mobileUploadTasks!,
        onRemoveImage: onRemoveMobileImage!,
        onRetryImage: onRetryMobileImage!,
      );
    }

    // ── Desktop: Quill editor ──
    return Column(
      children: [
        TextField(
          controller: titleController,
          decoration: const InputDecoration(
            hintText: '标题',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        quill.QuillSimpleToolbar(
          controller: quillController,
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
                onPressed: onPickAndUploadImage,
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
              controller: quillController,
              config: quill.QuillEditorConfig(
                placeholder: '请输入文本',
                padding: const EdgeInsets.all(16),
                onLaunchUrl: _handleLaunchUrl,
                embedBuilders: [
                  ...FlutterQuillEmbeds.editorBuilders(
                    imageEmbedConfig: QuillEditorImageEmbedConfig(
                      onImageClicked: (url) {},
                    ),
                  ),
                  const _DividerEmbedBuilder(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileEditorBody extends StatefulWidget {
  const _MobileEditorBody({
    required this.titleController,
    required this.bodyController,
    required this.uploadTasks,
    required this.onRemoveImage,
    required this.onRetryImage,
  });

  final TextEditingController titleController;
  final TextEditingController bodyController;
  final RxList<UploadTask> uploadTasks;
  final void Function(int index) onRemoveImage;
  final void Function(UploadTask task) onRetryImage;

  @override
  State<_MobileEditorBody> createState() => _MobileEditorBodyState();
}

class _MobileEditorBodyState extends State<_MobileEditorBody> {
  final _titleFocus = FocusNode();
  final _bodyFocus = FocusNode();

  @override
  void dispose() {
    _titleFocus.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title field
        TextField(
          controller: widget.titleController,
          focusNode: _titleFocus,
          maxLines: 1,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          decoration: const InputDecoration(
            hintText: '请输入标题',
            hintStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xff505050),
            ),
            border: InputBorder.none,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const Divider(height: 1, color: Color(0xff2A2A2A)),
        // Body text field
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: widget.bodyController,
                  focusNode: _bodyFocus,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xffE0E0E0),
                    height: 1.6,
                  ),
                  decoration: const InputDecoration(
                    hintText: '说点什么吧...',
                    hintStyle: TextStyle(
                      fontSize: 16,
                      color: Color(0xff505050),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
                // Inline image thumbnails with upload status
                Obx(() {
                  if (widget.uploadTasks.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(widget.uploadTasks.length, (i) {
                        final task = widget.uploadTasks[i];
                        return _MobileImageTile(
                          task: task,
                          allTasks: widget.uploadTasks,
                          onRemove: () => widget.onRemoveImage(i),
                          onRetry: () => widget.onRetryImage(task),
                        );
                      }),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileImageTile extends StatelessWidget {
  const _MobileImageTile({
    required this.task,
    required this.allTasks,
    required this.onRemove,
    required this.onRetry,
  });

  final UploadTask task;
  final List<UploadTask> allTasks;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final status = task.status.value;
      final progress = task.progress.value;

      return SizedBox(
        width: 90,
        height: 90,
        child: Stack(
          children: [
            // Preview image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildPreview(context, status),
            ),
            // Overlay for non-done states
            if (status != UploadStatus.done)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.55),
                    child: Center(
                      child: _buildIndicator(status, progress),
                    ),
                  ),
                ),
              ),
            // Remove button
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Color(0xCC000000),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close,
                      color: Colors.white, size: 14),
                ),
              ),
            ),
            // Retry button for errors
            if (status == UploadStatus.error)
              Positioned(
                bottom: 4,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: onRetry,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xffD7FF00),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '重试',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  void _openImageViewer(BuildContext context) {
    final doneTasks = allTasks
        .where((t) => t.status.value == UploadStatus.done && t.serverUrl != null)
        .toList();
    final doneUrls = doneTasks.map((t) => t.serverUrl!).toList();
    final doneIndex = doneTasks.indexWhere((t) => t.localId == task.localId);

    if (doneUrls.isEmpty) return;

    ImageViewer.show(
      context,
      imageUrls: doneUrls,
      initialIndex: doneIndex >= 0 ? doneIndex : 0,
    );
  }

  Widget _buildPreview(BuildContext context, UploadStatus status) {
    if (status == UploadStatus.done && task.serverUrl != null) {
      return GestureDetector(
        onTap: () => _openImageViewer(context),
        child: Image.network(
          task.serverUrl!,
          width: 90,
          height: 90,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 90,
            height: 90,
            color: const Color(0xff2A2A2A),
            child: const Icon(Icons.broken_image, color: Colors.grey),
          ),
        ),
      );
    }
    if (task.localPreviewBytes != null) {
      return Image.memory(
        task.localPreviewBytes!,
        width: 90,
        height: 90,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 90,
          height: 90,
          color: const Color(0xff2A2A2A),
          child: const Icon(Icons.image, color: Colors.grey),
        ),
      );
    }
    return Container(
      width: 90,
      height: 90,
      color: const Color(0xff2A2A2A),
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }

  Widget _buildIndicator(UploadStatus status, int progress) {
    switch (status) {
      case UploadStatus.pending:
      case UploadStatus.compressing:
        return SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: status == UploadStatus.compressing
                ? const Color(0xffFBC02D)
                : const Color(0xffD7FF00),
          ),
        );
      case UploadStatus.uploading:
        return SizedBox(
          width: 28,
          height: 28,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: progress / 100,
                strokeWidth: 2.5,
                backgroundColor: Colors.white24,
                color: const Color(0xffD7FF00),
              ),
              Center(
                child: Text(
                  '$progress%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      case UploadStatus.error:
        return const Icon(Icons.error_outline, color: Colors.redAccent, size: 24);
      case UploadStatus.done:
        return const SizedBox.shrink();
    }
  }
}

class _DividerEmbedBuilder extends quill.EmbedBuilder {
  const _DividerEmbedBuilder();

  @override
  String get key => 'divider';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Color(0xff313132),
      ),
    );
  }
}
