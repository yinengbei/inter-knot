import 'package:flutter/material.dart';
import 'package:inter_knot/helpers/image_compress_helper.dart';

class CreateDiscussionMobileNav extends StatelessWidget {
  const CreateDiscussionMobileNav({
    super.key,
    required this.isLoading,
    required this.onPickImage,
    required this.onSubmit,
    required this.selectedFormat,
    required this.onFormatChanged,
    this.imageCount = 0,
    this.uploadingCount = 0,
  });

  final bool isLoading;
  final VoidCallback onPickImage;
  final VoidCallback onSubmit;
  final UploadImageFormat selectedFormat;
  final ValueChanged<UploadImageFormat> onFormatChanged;
  final int imageCount;
  final int uploadingCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: const BoxDecoration(
        color: Color(0xff181818),
        border: Border(
          top: BorderSide(color: Color(0xff2A2A2A), width: 1),
        ),
      ),
      child: Row(
        children: [
          _ToolButton(
            icon: Icons.image_outlined,
            label: imageCount > 0 ? '$imageCount' : null,
            sublabel: uploadingCount > 0 ? '上传中$uploadingCount' : null,
            onTap: onPickImage,
          ),
          _FormatToggle(
            selectedFormat: selectedFormat,
            onChanged: onFormatChanged,
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: isLoading
                ? const SizedBox(
                    width: 80,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xffD7FF00),
                        ),
                      ),
                    ),
                  )
                : GestureDetector(
                    onTap: onSubmit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xffD7FF00),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '发布',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
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

class _FormatToggle extends StatelessWidget {
  const _FormatToggle({
    required this.selectedFormat,
    required this.onChanged,
  });

  final UploadImageFormat selectedFormat;
  final ValueChanged<UploadImageFormat> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xff101010),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xff2A2A2A)),
      ),
      child: Row(
        children: [
          _SmallFormatButton(
            label: 'WebP',
            selected: selectedFormat == UploadImageFormat.webp,
            onTap: () => onChanged(UploadImageFormat.webp),
          ),
          _SmallFormatButton(
            label: 'JPG',
            selected: selectedFormat == UploadImageFormat.jpg,
            onTap: () => onChanged(UploadImageFormat.jpg),
          ),
        ],
      ),
    );
  }
}

class _SmallFormatButton extends StatelessWidget {
  const _SmallFormatButton({
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xffD7FF00) : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.black : const Color(0xffA0A0A0),
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.onTap,
    this.label,
    this.sublabel,
  });

  final IconData icon;
  final String? label;
  final String? sublabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xffA0A0A0), size: 24),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(
                label!,
                style: const TextStyle(
                  color: Color(0xffD7FF00),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            if (sublabel != null) ...[
              const SizedBox(width: 6),
              Text(
                sublabel!,
                style: TextStyle(
                  color: const Color(0xffFBC02D).withValues(alpha: 0.85),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
