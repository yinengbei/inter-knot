import 'package:flutter/material.dart';
import 'package:inter_knot/helpers/image_compress_helper.dart';

class CreateDiscussionDesktopFooter extends StatelessWidget {
  const CreateDiscussionDesktopFooter({
    super.key,
    required this.isLoading,
    required this.onSubmit,
    required this.selectedFormat,
    required this.onFormatChanged,
  });

  final bool isLoading;
  final VoidCallback onSubmit;
  final UploadImageFormat selectedFormat;
  final ValueChanged<UploadImageFormat> onFormatChanged;

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
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xff101010),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xff2E2E2E)),
            ),
            child: Row(
              children: [
                _FormatButton(
                  label: 'WebP',
                  selected: selectedFormat == UploadImageFormat.webp,
                  onTap: () => onFormatChanged(UploadImageFormat.webp),
                ),
                const SizedBox(width: 6),
                _FormatButton(
                  label: 'JPG',
                  selected: selectedFormat == UploadImageFormat.jpg,
                  onTap: () => onFormatChanged(UploadImageFormat.jpg),
                ),
              ],
            ),
          ),
          const Spacer(),
          Material(
            color: const Color(0xff1A1A1A),
            borderRadius: BorderRadius.circular(28),
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: isLoading ? null : onSubmit,
              child: SizedBox(
                height: 56,
                child: Padding(
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
                        child: isLoading
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
          ),
        ],
      ),
    );
  }
}

class _FormatButton extends StatelessWidget {
  const _FormatButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xffD7FF00) : const Color(0xff1A1A1A),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : const Color(0xffC8C8C8),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
