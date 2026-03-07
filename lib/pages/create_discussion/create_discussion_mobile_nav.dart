import 'package:flutter/material.dart';

class CreateDiscussionMobileNav extends StatelessWidget {
  const CreateDiscussionMobileNav({
    super.key,
    required this.isLoading,
    required this.onPickImage,
    required this.onSubmit,
    this.showCompressionToggle = false,
    this.compressBeforeUpload = true,
    this.onCompressionChanged,
    this.imageCount = 0,
    this.uploadingCount = 0,
  });

  final bool isLoading;
  final VoidCallback onPickImage;
  final VoidCallback onSubmit;
  final bool showCompressionToggle;
  final bool compressBeforeUpload;
  final ValueChanged<bool>? onCompressionChanged;
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
          // Image picker button
          _ToolButton(
            icon: Icons.image_outlined,
            label: imageCount > 0 ? '$imageCount' : null,
            sublabel: uploadingCount > 0 ? '上传中$uploadingCount' : null,
            onTap: onPickImage,
          ),
          if (showCompressionToggle)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _CompressionSwitch(
                value: compressBeforeUpload,
                onChanged: isLoading ? null : onCompressionChanged,
              ),
            ),
          const Spacer(),
          // Submit button
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

class _CompressionSwitch extends StatelessWidget {
  const _CompressionSwitch({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 8, right: 2),
      decoration: BoxDecoration(
        color: const Color(0xff1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xff2A2A2A)),
      ),
      child: Row(
        children: [
          Text(
            '图片压缩',
            style: TextStyle(
              color: value ? const Color(0xffD7FF00) : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              activeThumbColor: const Color(0xffD7FF00),
              onChanged: onChanged,
            ),
          ),
        ],
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
