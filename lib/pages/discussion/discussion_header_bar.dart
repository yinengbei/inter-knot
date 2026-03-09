import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/avatar.dart';
import 'package:inter_knot/components/click_region.dart';
import 'package:inter_knot/components/my_chip.dart';
import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/gen/assets.gen.dart';
import 'package:inter_knot/helpers/dialog_helper.dart';
import 'package:inter_knot/helpers/time_formatter.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/pages/profile_page.dart';

class DiscussionHeaderBar extends StatelessWidget {
  const DiscussionHeaderBar({
    super.key,
    required this.discussion,
  });

  final DiscussionModel discussion;

  @override
  Widget build(BuildContext context) {
    final c = Get.find<Controller>();

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
          GestureDetector(
            onTap: () {
              if (discussion.author.authorId != null &&
                  discussion.author.authorId!.isNotEmpty) {
                showZZZDialog(
                  context: context,
                  pageBuilder: (context) => ProfilePage(
                    authorDocumentId: discussion.author.authorId!,
                  ),
                );
              }
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xff2D2D2D),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(maxRadius),
              ),
              child: Avatar(discussion.author.avatar),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Obx(() {
                        final user = c.user.value;
                        final authorId = c.authorId.value ?? user?.authorId;
                        final isMe = authorId != null &&
                            authorId == discussion.author.authorId;

                        return GestureDetector(
                          onTap: () {
                            if (discussion.author.authorId != null &&
                                discussion.author.authorId!.isNotEmpty) {
                              showZZZDialog(
                                context: context,
                                pageBuilder: (context) => ProfilePage(
                                  authorDocumentId: discussion.author.authorId!,
                                ),
                              );
                            }
                          },
                          child: Text(
                            discussion.author.name,
                            style: TextStyle(
                              fontSize: 16,
                              color:
                                  isMe ? const Color(0xFFFFBC2E) : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Lv.${discussion.author.level ?? 1}',
                      style: const TextStyle(
                        color: Color(0xffD7FF00),
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatRelativeTime(
                              discussion.createdAt,
                              fallbackPattern: 'yyyy-MM-dd HH:mm',
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xff808080),
                            ),
                          ),
                        ],
                      ),
                      if (discussion.author.login == owner)
                        const MyChip('绳网创始人'),
                      if (collaborators.contains(discussion.author.login))
                        const MyChip('绳网协作者'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ClickRegion(
            child: Assets.images.closeBtn.image(),
            onTap: () => Get.back(),
          ),
        ],
      ),
    );
  }
}
