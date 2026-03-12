import 'package:flutter/material.dart';

class CreateDiscussionDesktopFooter extends StatelessWidget {
  const CreateDiscussionDesktopFooter({
    super.key,
    required this.isPublishing,
    required this.onSubmit,
    this.submitEnabled = true,
    this.showCompressionToggle = false,
    this.compressBeforeUpload = true,
    this.onCompressionChanged,
  });

  final bool isPublishing;
  final VoidCallback onSubmit;
  final bool submitEnabled;
  final bool showCompressionToggle;
  final bool compressBeforeUpload;
  final ValueChanged<bool>? onCompressionChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (showCompressionToggle)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xff121212),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xff2A2A2A)),
                  ),
                  child: Row(
                    children: [
                      _CompressionOption(
                        label: '图片压缩',
                        selected: compressBeforeUpload,
                        onTap: isPublishing
                            ? null
                            : () => onCompressionChanged
                                ?.call(!compressBeforeUpload),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            const SizedBox.shrink(),
          Material(
            color: submitEnabled
                ? const Color(0xff1A1A1A)
                : const Color(0xff111111),
            borderRadius: BorderRadius.circular(28),
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: isPublishing || !submitEnabled ? null : onSubmit,
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xffFBC02D),
                        shape: BoxShape.circle,
                      ),
                      child: isPublishing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
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
    );
  }
}

class _CompressionOption extends StatelessWidget {
  const _CompressionOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xffD7FF00) : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.black : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
