import 'package:flutter/material.dart';

class CreateDiscussionMobileNav extends StatelessWidget {
  const CreateDiscussionMobileNav({
    super.key,
    required this.isLoading,
    required this.submitEnabled,
    required this.onPickImage,
    required this.onSubmit,
    this.imageCount = 0,
    this.uploadingCount = 0,
  });

  final bool isLoading;
  final bool submitEnabled;
  final VoidCallback onPickImage;
  final VoidCallback onSubmit;
  final int imageCount;
  final int uploadingCount;

  @override
  Widget build(BuildContext context) {
    final submitColor = submitEnabled
        ? const Color(0xffD7FF00)
        : Color.lerp(const Color(0xffD7FF00), Colors.white, 0.72)!;

    return Container(
      height: 62,
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
            sublabel:
                uploadingCount > 0 ? '\u4e0a\u4f20\u4e2d$uploadingCount' : null,
            onTap: onPickImage,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
              child: isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xffD7FF00),
                        ),
                      ),
                    )
                  : GestureDetector(
                      onTap: submitEnabled ? onSubmit : null,
                      child: Container(
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: submitColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '\u53d1\u5e03',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
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
