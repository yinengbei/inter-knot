import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/components/avatar.dart';
import 'package:inter_knot/components/click_region.dart';
import 'package:inter_knot/components/comment.dart';
import 'package:inter_knot/components/my_chip.dart';
import 'package:inter_knot/components/report_discussion_comment.dart';
import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/gen/assets.gen.dart';
import 'package:inter_knot/helpers/copy_text.dart';
import 'package:inter_knot/helpers/logger.dart';
import 'package:inter_knot/helpers/num2dur.dart';
import 'package:inter_knot/helpers/smooth_scroll.dart';
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
  final leftScrollController =
      ScrollController(); // New controller for left side
  final c = Get.find<Controller>();
  bool _isLoadingMore = false;
  bool _isInitialLoading = false;

  @override
  void initState() {
    super.initState();
    Future(() {
      c.history({widget.hData, ...c.history});
    });

    if (widget.discussion.comments.isEmpty) {
      _isInitialLoading = true;
    }

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
        while (scrollController.hasClients &&
            scrollController.position.maxScrollExtent == 0 &&
            widget.discussion.hasNextPage()) {
          await widget.discussion.fetchComments();
        }
      } catch (e, s) {
        logger.e('Failed to get scroll position', error: e, stackTrace: s);
      }
    }).whenComplete(() {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    leftScrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (mounted) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutQuart,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isDesktop = screenW >= 800;
    final double baseFactor = isDesktop ? 0.7 : 1.0;
    final double zoomScale = isDesktop ? 1.1 : 1.0;
    final double layoutFactor = baseFactor * zoomScale;

    return SafeArea(
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final safeW = constraints.maxWidth;
            final safeH = constraints.maxHeight;
            return SizedBox(
              width: safeW * layoutFactor,
              height: safeH * layoutFactor,
              child: FittedBox(
                child: SizedBox(
                  width: safeW * baseFactor,
                  height: safeH * baseFactor,
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
                                    image: Assets.images.discussionPageBgPoint
                                        .provider(),
                                    repeat: ImageRepeat.repeat,
                                  ),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xff161616),
                                      Color(0xff080808)
                                    ],
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
                                        borderRadius:
                                            BorderRadius.circular(maxRadius),
                                      ),
                                      child: Avatar(
                                          widget.discussion.author.avatar),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            widget.discussion.author.name,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      '发布时间：${widget.discussion.createdAt.toLocal().toString().split('.').first}',
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        color:
                                                            Color(0xff808080),
                                                      ),
                                                    ),
                                                    if (widget.discussion
                                                            .lastEditedAt !=
                                                        null)
                                                      Text(
                                                        '更新时间：${widget.discussion.lastEditedAt!.toLocal().toString().split('.').first}',
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          color:
                                                              Color(0xff808080),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                if (widget.discussion.author
                                                        .login ==
                                                    owner)
                                                  const MyChip('绳网创始人'),
                                                if (collaborators.contains(
                                                  widget
                                                      .discussion.author.login,
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
                                            constraints: const BoxConstraints(
                                                maxHeight: 500),
                                            width: double.infinity,
                                            child: Cover(
                                                discussion: widget.discussion),
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
                                                  onCommentAdded:
                                                      _scrollToBottom,
                                                ),
                                                const SizedBox(height: 16),
                                                const Divider(),
                                                if (widget.discussion.id ==
                                                    reportDiscussionNumber)
                                                  const ReportDiscussionComment()
                                                else
                                                  Comment(
                                                      discussion:
                                                          widget.discussion,
                                                      loading:
                                                          _isInitialLoading),
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
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              color: const Color(0xff070707),
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              child: LayoutBuilder(
                                                builder:
                                                    (context, constraints) {
                                                  return AdaptiveSmoothScroll(
                                                    controller:
                                                        leftScrollController,
                                                    scrollSpeed: 0.5,
                                                    builder: (context,
                                                            physics) =>
                                                        SingleChildScrollView(
                                                      controller:
                                                          leftScrollController,
                                                      physics: physics,
                                                      child: Column(
                                                        children: [
                                                          SizedBox(
                                                            height: constraints
                                                                    .maxHeight -
                                                                120,
                                                            child: Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .fromLTRB(
                                                                      16,
                                                                      16,
                                                                      24,
                                                                      16),
                                                              child: ClipRRect(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            12),
                                                                child:
                                                                    Container(
                                                                  width: double
                                                                      .infinity,
                                                                  foregroundDecoration:
                                                                      BoxDecoration(
                                                                    border:
                                                                        Border
                                                                            .all(
                                                                      color: const Color(
                                                                          0xff313132),
                                                                      width: 4,
                                                                    ),
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            12),
                                                                  ),
                                                                  child: Cover(
                                                                    discussion:
                                                                        widget
                                                                            .discussion,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          DiscussionDetailBox(
                                                            discussion: widget
                                                                .discussion,
                                                            hData: widget.hData,
                                                          ),
                                                        ],
                                                      ),
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
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xff070707),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: const Color(0xff313132),
                                                width: 4,
                                              ),
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Column(
                                                children: [
                                                  Expanded(
                                                    child: AdaptiveSmoothScroll(
                                                      controller:
                                                          scrollController,
                                                      scrollSpeed: 0.5,
                                                      builder: (context,
                                                              physics) =>
                                                          SingleChildScrollView(
                                                        controller:
                                                            scrollController,
                                                        physics: physics,
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(16.0),
                                                          child: Column(
                                                            children: [
                                                              if (widget
                                                                      .discussion
                                                                      .id ==
                                                                  reportDiscussionNumber)
                                                                const ReportDiscussionComment()
                                                              else
                                                                Comment(
                                                                    discussion:
                                                                        widget
                                                                            .discussion,
                                                                    loading:
                                                                        _isInitialLoading),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            16.0),
                                                    decoration:
                                                        const BoxDecoration(
                                                      border: Border(
                                                        top: BorderSide(
                                                          color:
                                                              Color(0xff313132),
                                                        ),
                                                      ),
                                                    ),
                                                    child:
                                                        DiscussionActionButtons(
                                                      discussion:
                                                          widget.discussion,
                                                      hData: widget.hData,
                                                      onCommentAdded:
                                                          _scrollToBottom,
                                                    ),
                                                  ),
                                                ],
                                              ),
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
          },
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
                child: HtmlWidget(
                  discussion.bodyHTML,
                  textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 16,
                    fontFamily: 'ZhCn',
                    fontFamilyFallback: const ['ZhCn'],
                  ),
                  onTapUrl: (url) {
                    launchUrlString(url);
                    return true;
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

class DiscussionActionButtons extends StatefulWidget {
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
  State<DiscussionActionButtons> createState() =>
      _DiscussionActionButtonsState();
}

class _DiscussionActionButtonsState extends State<DiscussionActionButtons>
    with SingleTickerProviderStateMixin {
  final c = Get.find<Controller>();
  late final api = Get.find<Api>();

  bool _isWriting = false;
  bool _isLoading = false;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final AnimationController _controller;
  late final Animation<double> _sizeAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _sizeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    // Initially expanded (value 1.0)
    _controller.value = 1.0;
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _textController.text.trim();
    if (content.isEmpty) {
      Get.rawSnackbar(message: '评论内容不能为空');
      return;
    }

    if (!c.isLogin.value) {
      Get.to(() => const LoginPage());
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = c.user.value;
      final authorId = c.authorId.value ?? await c.ensureAuthorForUser(user);
      if (authorId == null || authorId.isEmpty) {
        Get.rawSnackbar(message: '无法关联作者，请重新登录后再试');
        return;
      }

      final res = await api.addDiscussionComment(
        widget.discussion.id,
        content,
        authorId: authorId,
      );

      if (res.hasError) throw Exception(res.statusText ?? 'Unknown error');

      if (res.body?['errors'] != null) {
        final errors = res.body!['errors'] as List<dynamic>;
        if (errors.isNotEmpty) {
          final first = errors[0];
          final msg = first is Map ? first['message']?.toString() : null;
          throw Exception(msg ?? 'Failed to add comment');
        }
      }

      _textController.clear();
      _cancel();

      widget.discussion.comments.clear();
      await widget.discussion.fetchComments();
      widget.onCommentAdded?.call();
      Get.rawSnackbar(message: '评论发布成功');
    } catch (e) {
      Get.rawSnackbar(message: '评论发布失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleTap() {
    if (!c.isLogin.value) {
      Get.to(() => const LoginPage());
      return;
    }

    if (_isWriting) {
      _submit();
    } else {
      setState(() => _isWriting = true);
      _controller.reverse();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  void _cancel() {
    setState(() => _isWriting = false);
    _controller.forward();
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapOutside: (_) {
        if (_isWriting) _cancel();
      },
      child: Row(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xff222222),
                borderRadius: BorderRadius.circular(maxRadius),
                border: Border.all(color: const Color(0xff2D2D2D), width: 4),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final fullWidth = constraints.maxWidth;
                  const iconWidth = 48.0;

                  return AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      // _controller goes from 1.0 (closed) to 0.0 (open)
                      final progress = 1.0 - _controller.value;
                      final curve = Curves.easeInOut.transform(progress);

                      final inputWidth =
                          (fullWidth - iconWidth) * curve; // 0 -> max
                      final buttonWidth = fullWidth - inputWidth; // max -> icon

                      return Row(
                        children: [
                          // Input Section
                          SizedBox(
                            width: inputWidth,
                            child: ClipRect(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                widthFactor: 1.0,
                                child: UnconstrainedBox(
                                  alignment: Alignment.centerLeft,
                                  constrainedAxis: Axis.vertical,
                                  child: SizedBox(
                                    width: fullWidth - iconWidth,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0),
                                      child: CallbackShortcuts(
                                        bindings: {
                                          const SingleActivator(
                                                  LogicalKeyboardKey.escape):
                                              _cancel,
                                        },
                                        child: TextField(
                                          controller: _textController,
                                          focusNode: _focusNode,
                                          style: const TextStyle(
                                              fontSize: 16,
                                              color: Colors.white),
                                          cursorColor: Colors.white,
                                          decoration:
                                              const InputDecoration.collapsed(
                                            hintText: '请输入文本...',
                                            hintStyle:
                                                TextStyle(color: Colors.grey),
                                          ),
                                          onSubmitted: (_) => _submit(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Button Section
                          SizedBox(
                            width: buttonWidth,
                            child: ClickRegion(
                              onTap: _handleTap,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Send Icon (Visible when open)
                                  Opacity(
                                    opacity: curve,
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white),
                                          )
                                        : const Icon(Icons.send,
                                            key: ValueKey('send')),
                                  ),
                                  // Write Comment Text (Visible when closed)
                                  Opacity(
                                    opacity: 1.0 - curve,
                                    child: Transform.translate(
                                      offset: Offset(-50 * curve,
                                          0), // Slide left slightly
                                      child: const UnconstrainedBox(
                                        constrainedAxis: Axis.vertical,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
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
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _sizeAnimation,
            axis: Axis.horizontal,
            axisAlignment: -1.0,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Row(
                children: [
                  if (canReport(widget.discussion, widget.hData.isPin)) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: '举报',
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xff222222),
                          borderRadius: BorderRadius.circular(maxRadius),
                          border: Border.all(
                              color: const Color(0xff2D2D2D), width: 4),
                        ),
                        child: ClickRegion(
                          onTap: () {
                            Future.delayed(3.s).then(
                              (_) => launchUrlString(
                                'https://github.com/share121/inter-knot/discussions/$reportDiscussionNumber#new_comment_form',
                              ),
                            );
                            copyText(
                              '违规讨论：#${widget.discussion.id}\n举报原因：',
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
                    final isLiked = c.bookmarks
                        .map((e) => e.id)
                        .contains(widget.discussion.id);
                    return Tooltip(
                      message: isLiked ? '不喜欢' : '喜欢',
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xff222222),
                          borderRadius: BorderRadius.circular(maxRadius),
                          border: Border.all(
                              color: const Color(0xff2D2D2D), width: 4),
                        ),
                        child: ClickRegion(
                          onTap: () => c.toggleFavorite(widget.hData),
                          child: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_outline,
                            color: isLiked ? Colors.red : null,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Cover extends StatefulWidget {
  const Cover({super.key, required this.discussion});

  final DiscussionModel discussion;

  @override
  State<Cover> createState() => _CoverState();
}

class _CoverState extends State<Cover> {
  final _controller = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final covers = widget.discussion.covers;

    if (covers.isEmpty) {
      return Assets.images.defaultCover.image(fit: BoxFit.contain);
    }

    if (covers.length == 1) {
      return ClickRegion(
        onTap: () => launchUrlString(covers.first),
        child: CachedNetworkImage(
          imageUrl: covers.first,
          fit: BoxFit.contain,
          progressIndicatorBuilder: (context, url, p) {
            return Center(
              child: CircularProgressIndicator(
                value: p.totalSize == null ? null : p.downloaded / p.totalSize!,
              ),
            );
          },
          errorWidget: (context, url, error) =>
              Assets.images.defaultCover.image(fit: BoxFit.contain),
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          ScrollConfiguration(
            behavior: const _CoverScrollBehavior(),
            child: PageView.builder(
              controller: _controller,
              itemCount: covers.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final url = covers[index];
                return ClickRegion(
                  onTap: () => launchUrlString(url),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      progressIndicatorBuilder: (context, url, p) {
                        return Center(
                          child: CircularProgressIndicator(
                            value: p.totalSize == null
                                ? null
                                : p.downloaded / p.totalSize!,
                          ),
                        );
                      },
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[800],
                        child:
                            const Icon(Icons.broken_image, color: Colors.white),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (covers.length > 1)
            Positioned.fill(
              left: 8,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _NavButton(
                  icon: Icons.chevron_left,
                  onTap: () => _goToPage(_currentIndex - 1, covers.length),
                ),
              ),
            ),
          if (covers.length > 1)
            Positioned.fill(
              right: 8,
              child: Align(
                alignment: Alignment.centerRight,
                child: _NavButton(
                  icon: Icons.chevron_right,
                  onTap: () => _goToPage(_currentIndex + 1, covers.length),
                ),
              ),
            ),
          Positioned(
            bottom: 8,
            child: IgnorePointer(
              child: SizedBox(
                height: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(covers.length, (i) {
                    final isActive = i == _currentIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xffFBC02D)
                            : const Color(0xff2E2E2E),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _goToPage(int index, int total) {
    if (total <= 1) return;
    final target = index.clamp(0, total - 1);
    if (target == _currentIndex) return;
    _controller.animateToPage(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xB3000000),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _CoverScrollBehavior extends MaterialScrollBehavior {
  const _CoverScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.unknown,
      };
}
