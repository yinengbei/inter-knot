import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/image_viewer.dart';
import 'package:inter_knot/helpers/upload_task.dart';
import 'package:url_launcher/url_launcher_string.dart';

class CreateDiscussionEditorPage extends StatelessWidget {
  const CreateDiscussionEditorPage({
    super.key,
    required this.titleController,
    required this.bodyController,
    required this.onPickAndUploadImage,
    this.isMobile = false,
    this.mobileUploadTasks,
    this.onRemoveMobileImage,
    this.onRetryMobileImage,
  });

  final TextEditingController titleController;
  final TextEditingController bodyController;
  final VoidCallback onPickAndUploadImage;

  // Mobile-only
  final bool isMobile;
  final RxList<UploadTask>? mobileUploadTasks;
  final void Function(int index)? onRemoveMobileImage;
  final void Function(UploadTask task)? onRetryMobileImage;

  bool _isCtrlPressed() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight);
  }

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return _MobileEditorBody(
        titleController: titleController,
        bodyController: bodyController,
        uploadTasks: mobileUploadTasks!,
        onRemoveImage: onRemoveMobileImage!,
        onRetryImage: onRetryMobileImage!,
      );
    }

    return _DesktopEditorBody(
      titleController: titleController,
      bodyController: bodyController,
      onPickAndUploadImage: onPickAndUploadImage,
    );
  }
}

class _DesktopEditorBody extends StatefulWidget {
  const _DesktopEditorBody({
    required this.titleController,
    required this.bodyController,
    required this.onPickAndUploadImage,
  });

  final TextEditingController titleController;
  final TextEditingController bodyController;
  final VoidCallback onPickAndUploadImage;

  @override
  State<_DesktopEditorBody> createState() => _DesktopEditorBodyState();
}

class _DesktopEditorBodyState extends State<_DesktopEditorBody> {
  final _titleFocus = FocusNode();
  final _bodyFocus = FocusNode();
  final _toolbarScrollController = ScrollController();
  final _undoController = UndoHistoryController();
  bool _showToolbarScrollbar = false;

  @override
  void dispose() {
    _toolbarScrollController.dispose();
    _undoController.dispose();
    _titleFocus.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  TextSelection get _selection {
    final selection = widget.bodyController.selection;
    if (!selection.isValid) {
      final offset = widget.bodyController.text.length;
      return TextSelection.collapsed(offset: offset);
    }
    return selection;
  }

  void _updateText(
    String newText, {
    required int selectionStart,
    required int selectionEnd,
  }) {
    widget.bodyController.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: selectionStart,
        extentOffset: selectionEnd,
      ),
    );
    _bodyFocus.requestFocus();
  }

  void _replaceSelection({
    required String replacement,
    int? selectionStart,
    int? selectionEnd,
  }) {
    final selection = _selection;
    final text = widget.bodyController.text;
    final start = selection.start;
    final end = selection.end;
    final newText = text.replaceRange(start, end, replacement);
    final nextStart = selectionStart ?? start + replacement.length;
    final nextEnd = selectionEnd ?? nextStart;
    _updateText(
      newText,
      selectionStart: nextStart,
      selectionEnd: nextEnd,
    );
  }

  void _wrapSelection(String before, String after, {String placeholder = ''}) {
    final selection = _selection;
    final selected = selection.textInside(widget.bodyController.text);
    final content = selected.isEmpty ? placeholder : selected;
    final replacement = '$before$content$after';
    final cursorStart = selection.start + before.length;
    _replaceSelection(
      replacement: replacement,
      selectionStart: cursorStart,
      selectionEnd: cursorStart + content.length,
    );
  }

  ({int start, int end}) _selectedLineRange() {
    final text = widget.bodyController.text;
    final selection = _selection;
    var start = selection.start;
    var end = selection.end;
    while (start > 0 && text[start - 1] != '\n') {
      start--;
    }
    while (end < text.length && text[end] != '\n') {
      end++;
    }
    return (start: start, end: end);
  }

  void _transformSelectedLines(List<String> Function(List<String> lines) transform) {
    final range = _selectedLineRange();
    final original = widget.bodyController.text.substring(range.start, range.end);
    final lines = original.split('\n');
    final updatedLines = transform(lines);
    final replacement = updatedLines.join('\n');
    final text = widget.bodyController.text.replaceRange(
      range.start,
      range.end,
      replacement,
    );
    _updateText(
      text,
      selectionStart: range.start,
      selectionEnd: range.start + replacement.length,
    );
  }

  void _toggleSymmetricMarker(String marker) {
    final selection = _selection;
    final text = widget.bodyController.text;
    final selected = selection.textInside(text);
    final hasMarker =
        selected.startsWith(marker) && selected.endsWith(marker) &&
        selected.length >= marker.length * 2;
    if (hasMarker) {
      final unwrapped =
          selected.substring(marker.length, selected.length - marker.length);
      _replaceSelection(
        replacement: unwrapped,
        selectionStart: selection.start,
        selectionEnd: selection.start + unwrapped.length,
      );
      return;
    }
    _wrapSelection(marker, marker, placeholder: '文本');
  }

  void _applyHeading(String prefix) {
    _transformSelectedLines((lines) {
      return lines.map((line) {
        final withoutHeading = line.replaceFirst(RegExp(r'^\s{0,3}#{1,6}\s+'), '');
        if (prefix.isEmpty) return withoutHeading;
        return '$prefix$withoutHeading';
      }).toList();
    });
  }

  void _toggleFixedPrefix(String prefix) {
    _transformSelectedLines((lines) {
      final allPrefixed = lines.where((line) => line.isNotEmpty).isNotEmpty &&
          lines.where((line) => line.isNotEmpty).every((line) => line.startsWith(prefix));
      return lines.map((line) {
        if (line.isEmpty) return line;
        if (allPrefixed) {
          return line.startsWith(prefix) ? line.substring(prefix.length) : line;
        }
        return '$prefix$line';
      }).toList();
    });
  }

  void _toggleOrderedList() {
    _transformSelectedLines((lines) {
      final nonEmpty = lines.where((line) => line.isNotEmpty).toList();
      final allOrdered = nonEmpty.isNotEmpty &&
          nonEmpty.every((line) => RegExp(r'^\d+\.\s').hasMatch(line));
      var index = 1;
      return lines.map((line) {
        if (line.isEmpty) return line;
        if (allOrdered) {
          return line.replaceFirst(RegExp(r'^\d+\.\s'), '');
        }
        final stripped = line.replaceFirst(RegExp(r'^\d+\.\s'), '');
        return '${index++}. $stripped';
      }).toList();
    });
  }

  void _toggleTaskList() {
    _transformSelectedLines((lines) {
      final nonEmpty = lines.where((line) => line.isNotEmpty).toList();
      final allTask = nonEmpty.isNotEmpty &&
          nonEmpty.every((line) => line.startsWith('- [ ] '));
      return lines.map((line) {
        if (line.isEmpty) return line;
        if (allTask) {
          return line.replaceFirst('- [ ] ', '');
        }
        return '- [ ] $line';
      }).toList();
    });
  }

  void _adjustIndent(bool increase) {
    _transformSelectedLines((lines) {
      return lines.map((line) {
        if (line.isEmpty) return line;
        if (increase) return '  $line';
        if (line.startsWith('  ')) return line.substring(2);
        if (line.startsWith('\t')) return line.substring(1);
        return line;
      }).toList();
    });
  }

  void _insertCodeBlock() {
    final selection = _selection;
    final selected = selection.textInside(widget.bodyController.text);
    final content = selected.isEmpty ? '代码' : selected;
    final replacement = '```\n$content\n```';
    _replaceSelection(
      replacement: replacement,
      selectionStart: selection.start + 4,
      selectionEnd: selection.start + 4 + content.length,
    );
  }

  void _clearFormatting() {
    final selection = _selection;
    final selected = selection.textInside(widget.bodyController.text);
    if (selected.isNotEmpty) {
      var cleaned = selected;
      cleaned = cleaned.replaceAllMapped(
        RegExp(r'(\*\*|__|~~|`)(.*?)\1', dotAll: true),
        (m) => m[2] ?? '',
      );
      cleaned = cleaned.replaceAllMapped(
        RegExp(r'\[(.*?)\]\((.*?)\)', dotAll: true),
        (m) => m[1] ?? '',
      );
      _replaceSelection(
        replacement: cleaned,
        selectionStart: selection.start,
        selectionEnd: selection.start + cleaned.length,
      );
      return;
    }

    _transformSelectedLines((lines) {
      return lines.map((line) {
        var cleaned = line;
        cleaned = cleaned.replaceFirst(RegExp(r'^\s{0,3}#{1,6}\s+'), '');
        cleaned = cleaned.replaceFirst(RegExp(r'^\d+\.\s'), '');
        cleaned = cleaned.replaceFirst(RegExp(r'^[-*+]\s'), '');
        cleaned = cleaned.replaceFirst(RegExp(r'^- \[ \]\s'), '');
        cleaned = cleaned.replaceFirst(RegExp(r'^>\s?'), '');
        cleaned = cleaned.replaceFirst(RegExp(r'^(  |\t)+'), '');
        return cleaned;
      }).toList();
    });
  }

  Widget _toolbarButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xff151515),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xff151515),
          disabledForegroundColor: Colors.white24,
          hoverColor: const Color(0xff2A2A2A),
          minimumSize: const Size(36, 36),
          maximumSize: const Size(36, 36),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    final items = <Widget>[
        ValueListenableBuilder<UndoHistoryValue>(
          valueListenable: _undoController,
          builder: (context, value, child) {
            return _toolbarButton(
              tooltip: '撤销',
              icon: Icons.undo,
              onPressed: value.canUndo ? _undoController.undo : null,
            );
          },
        ),
        ValueListenableBuilder<UndoHistoryValue>(
          valueListenable: _undoController,
          builder: (context, value, child) {
            return _toolbarButton(
              tooltip: '重做',
              icon: Icons.redo,
              onPressed: value.canRedo ? _undoController.redo : null,
            );
          },
        ),
        _toolbarButton(
          tooltip: '粗体',
          icon: Icons.format_bold,
          onPressed: () => _toggleSymmetricMarker('**'),
        ),
        _toolbarButton(
          tooltip: '斜体',
          icon: Icons.format_italic,
          onPressed: () => _toggleSymmetricMarker('*'),
        ),
        _toolbarButton(
          tooltip: '下划线',
          icon: Icons.format_underlined,
          onPressed: () => _wrapSelection('<u>', '</u>', placeholder: '文本'),
        ),
        _toolbarButton(
          tooltip: '删除线',
          icon: Icons.format_strikethrough,
          onPressed: () => _toggleSymmetricMarker('~~'),
        ),
        _toolbarButton(
          tooltip: '内嵌代码',
          icon: Icons.code,
          onPressed: () => _toggleSymmetricMarker('`'),
        ),
        _toolbarButton(
          tooltip: '清除格式',
          icon: Icons.format_clear,
          onPressed: _clearFormatting,
        ),
        PopupMenuButton<String>(
          tooltip: '标题样式',
          color: const Color(0xff1A1A1A),
          onSelected: _applyHeading,
          itemBuilder: (context) => const [
            PopupMenuItem(value: '', child: Text('正文')),
            PopupMenuItem(value: '# ', child: Text('标题 1')),
            PopupMenuItem(value: '## ', child: Text('标题 2')),
            PopupMenuItem(value: '### ', child: Text('标题 3')),
          ],
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xff151515),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.title, size: 18, color: Colors.white),
          ),
        ),
        _toolbarButton(
          tooltip: '有序列表',
          icon: Icons.format_list_numbered,
          onPressed: _toggleOrderedList,
        ),
        _toolbarButton(
          tooltip: '无序列表',
          icon: Icons.format_list_bulleted,
          onPressed: () => _toggleFixedPrefix('- '),
        ),
        _toolbarButton(
          tooltip: '任务列表',
          icon: Icons.checklist,
          onPressed: _toggleTaskList,
        ),
        _toolbarButton(
          tooltip: '代码块',
          icon: Icons.data_object,
          onPressed: _insertCodeBlock,
        ),
        _toolbarButton(
          tooltip: '引言',
          icon: Icons.format_quote,
          onPressed: () => _toggleFixedPrefix('> '),
        ),
        _toolbarButton(
          tooltip: '增加缩进',
          icon: Icons.format_indent_increase,
          onPressed: () => _adjustIndent(true),
        ),
        _toolbarButton(
          tooltip: '减少缩进',
          icon: Icons.format_indent_decrease,
          onPressed: () => _adjustIndent(false),
        ),
        _toolbarButton(
          tooltip: '插入链接',
          icon: Icons.link,
          onPressed: () => _wrapSelection('[', '](https://)', placeholder: '链接文字'),
        ),
        _toolbarButton(
          tooltip: '插入图片',
          icon: Icons.image_outlined,
          onPressed: widget.onPickAndUploadImage,
        ),
      ];

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xff0F0F0F),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ScrollConfiguration(
        behavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
        ),
        child: MouseRegion(
          onEnter: (_) => setState(() => _showToolbarScrollbar = true),
          onExit: (_) => setState(() => _showToolbarScrollbar = false),
          child: Listener(
            onPointerSignal: (event) {
              if (event is! PointerScrollEvent ||
                  !_toolbarScrollController.hasClients) {
                return;
              }
              final nextOffset = (_toolbarScrollController.offset +
                      event.scrollDelta.dy +
                      event.scrollDelta.dx)
                  .clamp(
                    0.0,
                    _toolbarScrollController.position.maxScrollExtent,
                  );
              _toolbarScrollController.jumpTo(nextOffset);
            },
            child: Scrollbar(
              controller: _toolbarScrollController,
              thumbVisibility: _showToolbarScrollbar,
              interactive: true,
              notificationPredicate: (notification) => notification.depth == 0,
              child: SingleChildScrollView(
                controller: _toolbarScrollController,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      items[i],
                      if (i != items.length - 1) const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: widget.titleController,
          focusNode: _titleFocus,
          maxLines: 1,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: '标题',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildToolbar(),
            ],
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: TextField(
              controller: widget.bodyController,
              focusNode: _bodyFocus,
              maxLines: null,
              expands: true,
              keyboardType: TextInputType.multiline,
              textAlignVertical: TextAlignVertical.top,
              undoController: _undoController,
              mouseCursor: SystemMouseCursors.text,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xffE0E0E0),
                height: 1.7,
              ),
              decoration: const InputDecoration(
                hintText: '说点什么吧...\n\n支持 Markdown，例如：\n# 标题\n- 列表\n![图片](url)',
                hintStyle: TextStyle(
                  fontSize: 16,
                  color: Color(0xff505050),
                  height: 1.6,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
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
