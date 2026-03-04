import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';

class CreateDiscussionEditorPage extends StatelessWidget {
  const CreateDiscussionEditorPage({
    super.key,
    required this.titleController,
    required this.quillController,
    required this.onPickAndUploadImage,
    this.isMobile = false,
    this.mobileBodyController,
    this.mobileImages,
    this.onRemoveMobileImage,
  });

  final TextEditingController titleController;
  final quill.QuillController quillController;
  final VoidCallback onPickAndUploadImage;

  // Mobile-only
  final bool isMobile;
  final TextEditingController? mobileBodyController;
  final RxList<({String id, String url})>? mobileImages;
  final void Function(int index)? onRemoveMobileImage;

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
        images: mobileImages!,
        onRemoveImage: onRemoveMobileImage!,
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
    required this.images,
    required this.onRemoveImage,
  });

  final TextEditingController titleController;
  final TextEditingController bodyController;
  final RxList<({String id, String url})> images;
  final void Function(int index) onRemoveImage;

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
                // Inline image thumbnails
                Obx(() {
                  if (widget.images.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(widget.images.length, (i) {
                        final img = widget.images[i];
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                img.url,
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 90,
                                  height: 90,
                                  color: const Color(0xff2A2A2A),
                                  child: const Icon(Icons.broken_image,
                                      color: Colors.grey),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => widget.onRemoveImage(i),
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
                          ],
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
