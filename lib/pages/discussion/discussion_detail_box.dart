import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:inter_knot/components/image_viewer.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:markdown_widget/markdown_widget.dart' hide ImageViewer;
import 'package:url_launcher/url_launcher_string.dart';

class DiscussionDetailBox extends StatefulWidget {
  const DiscussionDetailBox({
    super.key,
    required this.discussion,
  });

  final DiscussionModel discussion;

  @override
  State<DiscussionDetailBox> createState() => _DiscussionDetailBoxState();
}

class _DiscussionDetailBoxState extends State<DiscussionDetailBox> {
  quill.QuillController? _quillController;
  int? _contentSignature;

  @override
  void initState() {
    super.initState();
    _syncRichTextController();
  }

  @override
  void didUpdateWidget(covariant DiscussionDetailBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncRichTextController();
  }

  @override
  void dispose() {
    _quillController?.dispose();
    super.dispose();
  }

  void _syncRichTextController() {
    final discussion = widget.discussion;
    final editorState = discussion.editorState;
    final nextSignature = Object.hash(
      discussion.id,
      discussion.lastEditedAt?.millisecondsSinceEpoch ?? 0,
      discussion.rawBodyText,
      editorState?.length ?? 0,
    );

    if (_contentSignature == nextSignature) return;
    _contentSignature = nextSignature;

    _quillController?.dispose();
    _quillController = null;

    if (editorState == null || editorState.isEmpty) return;

    try {
      _quillController = quill.QuillController(
        document: quill.Document.fromJson(editorState),
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
    } catch (_) {
      _quillController = null;
    }
  }

  Widget _buildMarkdownBody(DiscussionModel discussion) {
    return RepaintBoundary(
      child: SelectionArea(
        child: MarkdownWidget(
          data: discussion.rawBodyText,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          config: MarkdownConfig.darkConfig.copy(
            configs: [
              ImgConfig(
                builder: (url, attributes) {
                  return GestureDetector(
                    onTap: () => ImageViewer.show(
                      context,
                      imageUrls: [url],
                    ),
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image,
                        color: Colors.redAccent,
                      ),
                    ),
                  );
                },
              ),
              LinkConfig(
                style: const TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
                onTap: (url) {
                  if (url.isNotEmpty) {
                    launchUrlString(url);
                  }
                },
              ),
              const PConfig(
                textStyle: TextStyle(
                  fontSize: 16,
                  color: Color(0xffE0E0E0),
                ),
              ),
              PreConfig.darkConfig.copy(
                wrapper: (child, code, language) => Stack(
                  children: [
                    child,
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Text(
                        language,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRichBody(DiscussionModel discussion) {
    final controller = _quillController;
    if (controller == null) {
      return _buildMarkdownBody(discussion);
    }

    return RepaintBoundary(
      child: quill.QuillEditor.basic(
        controller: controller,
        config: quill.QuillEditorConfig(
          scrollable: false,
          padding: EdgeInsets.zero,
          autoFocus: false,
          showCursor: false,
          enableSelectionToolbar: true,
          onLaunchUrl: (url) {
            launchUrlString(url);
          },
          embedBuilders: FlutterQuillEmbeds.editorBuilders(
            imageEmbedConfig: QuillEditorImageEmbedConfig(
              onImageClicked: (url) => ImageViewer.show(
                context,
                imageUrls: [url],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final discussion = widget.discussion;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                discussion.title,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 16),
              _buildRichBody(discussion),
            ],
          ),
        ],
      ),
    );
  }
}
