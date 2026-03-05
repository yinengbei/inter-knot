import 'package:flutter/material.dart';
import 'package:inter_knot/components/avatar.dart';
import 'package:inter_knot/gen/assets.gen.dart';
import 'package:inter_knot/models/notification.dart';
import 'package:intl/intl.dart';

class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onMarkRead,
  });

  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback onMarkRead;

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return DateFormat('MM-dd HH:mm').format(time);
    }
  }

  IconData _getIcon() {
    switch (notification.type) {
      case NotificationType.comment:
        return Icons.comment_outlined;
      case NotificationType.reply:
        return Icons.reply_outlined;
      case NotificationType.like:
        return Icons.thumb_up_outlined;
      case NotificationType.favorite:
        return Icons.favorite_outline;
      case NotificationType.mention:
        return Icons.alternate_email;
      case NotificationType.system:
        return Icons.notifications_outlined;
    }
  }

  Color _getIconColor() {
    switch (notification.type) {
      case NotificationType.comment:
        return const Color(0xff4A9EFF);
      case NotificationType.reply:
        return const Color(0xff9B59B6);
      case NotificationType.like:
        return const Color(0xffD7FF00);
      case NotificationType.favorite:
        return const Color(0xffE74C3C);
      case NotificationType.mention:
        return const Color(0xffF39C12);
      case NotificationType.system:
        return const Color(0xffD7FF00);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 640;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.symmetric(
            horizontal: isCompact ? 12 : 16,
            vertical: 6,
          ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: notification.isRead
                ? [
                    const Color(0xff1A1A1A).withValues(alpha: 0.6),
                    const Color(0xff0F0F0F).withValues(alpha: 0.6),
                  ]
                : [
                    const Color(0xff2A2A2A),
                    const Color(0xff1A1A1A),
                  ],
          ),
          border: Border.all(
            color: notification.isRead
                ? const Color(0xff2A2A2A)
                : const Color(0xff333333),
            width: 1,
          ),
          boxShadow: notification.isRead
              ? null
              : [
                  const BoxShadow(
                    color: Color(0x20000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: Assets.images.discussionPageBgPoint.provider(),
                repeat: ImageRepeat.repeat,
                opacity: 0.08,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(isCompact ? 12 : 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _getIconColor(),
                            width: 2,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Avatar(
                            notification.sender?.avatar,
                            size: isCompact ? 40 : 48,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: _getIconColor(),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xff1A1A1A),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            _getIcon(),
                            size: 10,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: isCompact ? 10 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.getTitle(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isCompact ? 14 : 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (!notification.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(left: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xffD7FF00),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xffD7FF00)
                                          .withValues(alpha: 0.5),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        if (notification.getDescription().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            notification.getDescription(),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: isCompact ? 12 : 13,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: isCompact ? 12 : 13,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatTime(notification.createdAt),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: isCompact ? 11 : 12,
                              ),
                            ),
                            if (!notification.isRead) ...[
                              const Spacer(),
                              GestureDetector(
                                onTap: () {
                                  onMarkRead();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xff333333),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xff444444),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    '标记已读',
                                    style: TextStyle(
                                      color: Colors.white
                                          .withValues(alpha: 0.9),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}
