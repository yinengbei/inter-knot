import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/avatar.dart';
import 'package:inter_knot/components/click_region.dart';
import 'package:inter_knot/components/comment.dart';
import 'package:inter_knot/components/comment_count.dart';
import 'package:inter_knot/components/comment_input_dialog.dart';
import 'package:inter_knot/components/my_chip.dart';
import 'package:inter_knot/components/report_discussion_comment.dart';
import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/gen/assets.gen.dart';
import 'package:inter_knot/helpers/copy_text.dart';
import 'package:inter_knot/helpers/logger.dart';
import 'package:inter_knot/helpers/num2dur.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/h_data.dart';
import 'package:inter_knot/pages/login_page.dart';
import 'package:url_launcher/url_launcher_string.dart';

class DiscussionPage extends StatefulWidget {
  const DiscussionPage({
    super.key,
    required this.discussion,
    required this.hData,
  });

  final DiscussionModel discussion;
  final HDataModel hData;

  @override
  State<DiscussionPage> createState() => _DiscussionPageState();
}

class _DiscussionPageState extends State<DiscussionPage> {
  final scrollController = ScrollController();
  final c = Get.find<Controller>();
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    Future(() {
      c.history({widget.hData, ...c.history});
    });
    scrollController.addListener(() {
      if (_isLoadingMore) return;
      final maxScroll = scrollController.position.maxScrollExtent;
      final currentScroll = scrollController.position.pixels;
      if (maxScroll - currentScroll < 200 && widget.discussion.hasNextPage()) {
        _isLoadingMore = true;
        widget.discussion.fetchComments().then((_) {
          if (mounted) {
            setState(() {});
          }
        }).catchError((e) {
          logger.e('Error loading more comments', error: e);
        }).whenComplete(() {
          _isLoadingMore = false;
        });
      }
    });
    widget.discussion.fetchComments().then((e) async {
      try {
        while (scrollController.position.maxScrollExtent == 0 &&
            widget.discussion.hasNextPage()) {
          await widget.discussion.fetchComments();
        }
        if (mounted) {
          setState(() {});
        }
      } catch (e, s) {
        logger.e('Failed to get scroll position', error: e, stackTrace: s);
      }
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    return SafeArea(
      child: Center(
        child: FractionallySizedBox(
          widthFactor: screenW < 800 ? 1 : 0.7,
          heightFactor: screenW < 800 ? 1 : 0.7,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color.fromARGB(59, 255, 255, 255),
              borderRadius: screenW < 800
                  ? BorderRadius.zero
                  : const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: screenW < 800
                    ? BorderRadius.zero
                    : const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
              ),
              child: ClipRRect(
                borderRadius: screenW < 800
                    ? BorderRadius.zero
                    : const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                child: Scaffold(
                  backgroundColor: const Color(0xff121212),
                  body: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image:
                                Assets.images.discussionPageBgPoint.provider(),
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
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xff2D2D2D),
                                  width: 3,
                                ),
                                borderRadius: BorderRadius.circular(maxRadius),
                              ),
                              child: Avatar(widget.discussion.author.avatar),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.discussion.author.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Color(0xff808080),
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '发布时间：${widget.discussion.createdAt.toLocal().toString().split('.').first}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xff606060),
                                    ),
                                  ),
                                  if (widget.discussion.lastEditedAt != null)
                                    Text(
                                      '更新时间：${widget.discussion.lastEditedAt!.toLocal().toString().split('.').first}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xff606060),
                                      ),
                                    ),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        CommentCount(
                                          discussion: widget.discussion,
                                          color: const Color(0xff808080),
                                        ),
                                        if (widget.discussion.author.login ==
                                            owner)
                                          const MyChip('绳网创始人'),
                                        if (collaborators.contains(
                                          widget.discussion.author.login,
                                        ))
                                          const MyChip(
                                            '绳网协作者',
                                          ),
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
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, con) {
                            if (con.maxWidth < 600) {
                              return ListView(
                                controller: scrollController,
                                children: [
                                  Container(
                                    constraints:
                                        const BoxConstraints(maxHeight: 500),
                                    width: double.infinity,
                                    child: Cover(discussion: widget.discussion),
                                  ),
                                  DiscussionDetailBox(
                                    discussion: widget.discussion,
                                    hData: widget.hData,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: Column(
                                      children: [
                                        DiscussionActionButtons(
                                          discussion: widget.discussion,
                                          hData: widget.hData,
                                          onCommentAdded: () {
                                            if (mounted) setState(() {});
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        const Divider(),
                                        if (widget.discussion.id ==
                                            reportDiscussionNumber)
                                          const ReportDiscussionComment()
                                        else
                                          Comment(
                                              discussion: widget.discussion),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Container(
                                    margin: const EdgeInsets.only(
                                      top: 16,
                                      left: 16,
                                      right: 8,
                                      bottom: 16,
                                    ),
                                    height: double.infinity,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: const Color(0xff313132),
                                        width: 4,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      color: const Color(0xff070707),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          return SingleChildScrollView(
                                            child: Column(
                                              children: [
                                                SizedBox(
                                                  height:
                                                      constraints.maxHeight -
                                                          120,
                                                  child: Padding(
                                                    padding: const EdgeInsets
                                                        .fromLTRB(
                                                        16, 16, 24, 16),
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                      child: Container(
                                                        width: double.infinity,
                                                        foregroundDecoration:
                                                            BoxDecoration(
                                                          border: Border.all(
                                                            color: const Color(
                                                                0xff313132),
                                                            width: 4,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                        ),
                                                        child: Cover(
                                                          discussion:
                                                              widget.discussion,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                DiscussionDetailBox(
                                                  discussion: widget.discussion,
                                                  hData: widget.hData,
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    margin: const EdgeInsets.only(
                                      top: 16,
                                      left: 8,
                                      right: 16,
                                      bottom: 16,
                                    ),
                                    height: double.infinity,
                                    decoration: BoxDecoration(
                                      color: const Color(0xff070707),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(0xff313132),
                                        width: 4,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: SingleChildScrollView(
                                            controller: scrollController,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(16.0),
                                              child: Column(
                                                children: [
                                                  if (widget.discussion.id ==
                                                      reportDiscussionNumber)
                                                    const ReportDiscussionComment()
                                                  else
                                                    Comment(
                                                        discussion:
                                                            widget.discussion),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.all(16.0),
                                          decoration: const BoxDecoration(
                                            border: Border(
                                              top: BorderSide(
                                                color: Color(0xff313132),
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                          child: DiscussionActionButtons(
                                            discussion: widget.discussion,
                                            hData: widget.hData,
                                            onCommentAdded: () {
                                              if (mounted) setState(() {});
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DiscussionDetailBox extends StatefulWidget {
  const DiscussionDetailBox({
    super.key,
    required this.discussion,
    required this.hData,
  });

  final DiscussionModel discussion;
  final HDataModel hData;

  @override
  State<DiscussionDetailBox> createState() => _DiscussionDetailBoxState();
}

class _DiscussionDetailBoxState extends State<DiscussionDetailBox> {
  final c = Get.find<Controller>();

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
              SelectionArea(
                child: MarkdownBody(
                  data: discussion.rawBodyText,
                  selectable: true,
                  fitContent: false,
                  styleSheet:
                      MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                    p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 16,
                      fontFamily: 'ZhCn',
                      fontFamilyFallback: const ['ZhCn'],
                    ),
                    blockSpacing: 16,
                  ),
                  onTapLink: (text, href, title) {
                    if (href != null) {
                      launchUrlString(href);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DiscussionActionButtons extends StatelessWidget {
  const DiscussionActionButtons({
    super.key,
    required this.discussion,
    required this.hData,
    this.onCommentAdded,
  });

  final DiscussionModel discussion;
  final HDataModel hData;
  final VoidCallback? onCommentAdded;

  @override
  Widget build(BuildContext context) {
    final c = Get.find<Controller>();
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xff222222),
              borderRadius: BorderRadius.circular(maxRadius),
              border: Border.all(color: const Color(0xff2D2D2D), width: 4),
            ),
            child: ClickRegion(
              onTap: () {
                if (!c.isLogin.value) {
                  Get.to(() => const LoginPage());
                  return;
                }
                Get.dialog(
                  CommentInputDialog(
                    discussionId: discussion.id,
                    onCommentAdded: () {
                      discussion.comments.clear();
                      discussion.fetchComments().then((_) {
                        onCommentAdded?.call();
                      });
                    },
                  ),
                );
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_comment_outlined),
                  SizedBox(width: 8),
                  Text(
                    '写评论',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (canReport(discussion, hData.isPin)) ...[
          const SizedBox(width: 8),
          Tooltip(
            message: '举报',
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xff222222),
                borderRadius: BorderRadius.circular(maxRadius),
                border: Border.all(color: const Color(0xff2D2D2D), width: 4),
              ),
              child: ClickRegion(
                onTap: () {
                  Future.delayed(3.s).then(
                    (_) => launchUrlString(
                      'https://github.com/share121/inter-knot/discussions/$reportDiscussionNumber#new_comment_form',
                    ),
                  );
                  copyText(
                    '违规讨论：#${discussion.id}\n举报原因：',
                    title: '举报模板已复制',
                    msg: '3 秒后跳转到举报页',
                  );
                },
                child: const Icon(Icons.report_outlined),
              ),
            ),
          ),
        ],
        const SizedBox(width: 8),
        Obx(() {
          final isLiked = c.bookmarks.map((e) => e.id).contains(discussion.id);
          return Tooltip(
            message: isLiked ? '不喜欢' : '喜欢',
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xff222222),
                borderRadius: BorderRadius.circular(maxRadius),
                border: Border.all(color: const Color(0xff2D2D2D), width: 4),
              ),
              child: ClickRegion(
                onTap: () => c.toggleFavorite(hData),
                child: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_outline,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class Cover extends StatelessWidget {
  const Cover({super.key, required this.discussion});

  final DiscussionModel discussion;

  @override
  Widget build(BuildContext context) {
    return discussion.cover == null
        ? Assets.images.defaultCover.image(fit: BoxFit.contain)
        : ClickRegion(
            onTap: () => launchUrlString(discussion.cover!),
            child: Image.network(
              discussion.cover!,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, p) {
                if (p == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: p.expectedTotalBytes == null
                        ? null
                        : p.cumulativeBytesLoaded / p.expectedTotalBytes!,
                  ),
                );
              },
              errorBuilder: (context, e, s) =>
                  Assets.images.defaultCover.image(fit: BoxFit.contain),
            ),
          );
  }
}
