import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/avatar.dart';
import 'package:inter_knot/components/click_region.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/gen/assets.gen.dart';

class CreateDiscussionHeader extends StatelessWidget {
  const CreateDiscussionHeader({
    super.key,
    required this.controller,
    required this.title,
    required this.onClose,
    this.statusLabel,
    this.statusColor = const Color(0xffD7FF00),
  });

  final Controller controller;
  final String title;
  final VoidCallback onClose;
  final String? statusLabel;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        image: DecorationImage(
          image: Assets.images.discussionPageBgPoint.provider(),
          repeat: ImageRepeat.repeat,
        ),
        gradient: const LinearGradient(
          colors: [Color(0xff161616), Color(0xff080808)],
          begin: Alignment.topLeft,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Row(
        children: [
          Obx(() {
            final user = controller.user.value;
            return Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xff2D2D2D),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Avatar(
                user?.avatar,
                onTap: controller.isLogin.value
                    ? controller.pickAndUploadAvatar
                    : null,
              ),
            );
          }),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (statusLabel != null && statusLabel!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _EditorStatusChip(
                    label: statusLabel!,
                    color: statusColor,
                  ),
                ],
              ],
            ),
          ),
          ClickRegion(
            child: Assets.images.closeBtn.image(),
            onTap: onClose,
          ),
        ],
      ),
    );
  }
}

class _EditorStatusChip extends StatelessWidget {
  const _EditorStatusChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xff0D0D0D),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
