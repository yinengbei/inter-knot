import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/discussion_card.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/deferred_routes.dart';
import 'package:inter_knot/helpers/smooth_scroll.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/h_data.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

class DiscussionEmptyState extends StatelessWidget {
  const DiscussionEmptyState({
    super.key,
    required this.message,
    this.imageAsset,
    this.imageSize = 120,
    this.textStyle,
  });

  final String message;
  final String? imageAsset;
  final double imageSize;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageAsset != null && imageAsset!.isNotEmpty;
    final hasMessage = message.trim().isNotEmpty;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        if (hasImage)
          Image.asset(
            imageAsset!,
            width: imageSize,
            height: imageSize,
          ),
        if (hasImage && hasMessage) const SizedBox(height: 16),
        if (hasMessage)
          Text(
            message,
            style: textStyle,
          ),
      ],
    );
  }
}

class DiscussionGrid extends StatefulWidget {
  const DiscussionGrid({
    super.key,
    required this.list,
    required this.hasNextPage,
    this.fetchData,
    this.controller,
    this.reorderHistoryOnOpen = true,
  });

  final Set<HDataModel> list;
  final bool hasNextPage;
  final void Function()? fetchData;
  final ScrollController? controller;
  final bool reorderHistoryOnOpen;

  @override
  State<DiscussionGrid> createState() => _DiscussionGridState();
}

class _DiscussionGridState extends State<DiscussionGrid>
    with AutomaticKeepAliveClientMixin {
  late final ScrollController scrollController;
  bool _isLocalController = false;
  String _lastPrecachingSignature = '';

  Widget _buildInsertedPostAnimation(String id, Widget child) {
    if (id.isEmpty) return child;

    return Obx(() {
      final shouldAnimate =
          Get.find<Controller>().newlyInsertedPostIds.contains(id);

      return TweenAnimationBuilder<double>(
        key: ValueKey('insert-$id-${shouldAnimate ? 1 : 0}'),
        tween: Tween(begin: shouldAnimate ? 0 : 1, end: 1),
        duration: Duration(milliseconds: shouldAnimate ? 520 : 180),
        curve: shouldAnimate ? Curves.easeOutCubic : Curves.easeOut,
        child: child,
        builder: (context, value, builtChild) {
          final opacity = value < 0 ? 0.0 : (value > 1 ? 1.0 : value);
          final dy = (1 - value) * 16;
          final scale = 0.985 + (0.015 * value);
          return Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(0, dy),
              child: Transform.scale(
                scale: scale,
                child: builtChild,
              ),
            ),
          );
        },
      );
    });
  }

  @override
  bool get wantKeepAlive => true;

  Widget _buildCard(
      BuildContext context, HDataModel item, DiscussionModel discussion) {
    return DiscussionCard(
      discussion: discussion,
      hData: item,
      onTap: () async {
        final result = await showDiscussionPageDialog(
          context,
          discussion: discussion,
          hData: item,
          reorderHistoryOnOpen: widget.reorderHistoryOnOpen,
        );

        if (result == true) {
          if (widget.list is RxSet) {
            widget.list.remove(item);
          } else {
            setState(() {
              widget.list.remove(item);
            });
          }
        }
      },
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      scrollController = widget.controller!;
    } else {
      scrollController = ScrollController();
      _isLocalController = true;
    }
  }

  @override
  void didUpdateWidget(covariant DiscussionGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      if (oldWidget.controller == null) {
        if (_isLocalController) {
          scrollController.dispose();
          _isLocalController = false;
        }
      }
      if (widget.controller != null) {
        scrollController = widget.controller!;
        _isLocalController = false;
      } else {
        scrollController = ScrollController();
        _isLocalController = true;
      }
    }
  }

  @override
  void dispose() {
    if (_isLocalController) {
      scrollController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final list = widget.list;
    final items = list.toList(growable: false);
    _scheduleWebCoverPrecaching(items);
    final fetchData = widget.fetchData;
    final hasNextPage = widget.hasNextPage;

    if (list.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Obx(() {
                final isSearching = Get.find<Controller>().isSearching.value;
                final isLoading =
                    isSearching || (hasNextPage && fetchData != null);
                if (isLoading) {
                  return const DiscussionEmptyState(
                    message: '正在和绳网系统建立联系...',
                    imageAsset: 'assets/images/Bangboo.gif',
                    imageSize: 120,
                    textStyle: TextStyle(
                      color: Color(0xff808080),
                      fontSize: 14,
                    ),
                  );
                }
                return const DiscussionEmptyState(
                  message: '- 暂无相关帖子 -',
                  textStyle: TextStyle(
                    color: Color.fromARGB(255, 233, 233, 233),
                    fontSize: 16,
                  ),
                );
              }),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, con) {
        final width = MediaQuery.of(context).size.width;
        final isCompact = width < 640;
        final mainAxisSpacing = isCompact ? 10.0 : 12.0;
        final crossAxisSpacing = isCompact ? 8.0 : 10.0;
        final maxCrossAxisExtent = isCompact ? 273.0 : 264.0;

        final child = Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1450),
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification notification) {
                if (notification.depth == 0 &&
                    notification.metrics.extentAfter < 500 &&
                    hasNextPage) {
                  fetchData?.call();
                }
                return false;
              },
              child: WaterfallFlow.builder(
                controller: scrollController,
                cacheExtent: 0.0,
                physics: !isCompact
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(10, 16, 10, 10),
                gridDelegate: SliverWaterfallFlowDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: maxCrossAxisExtent,
                  mainAxisSpacing: mainAxisSpacing,
                  crossAxisSpacing: crossAxisSpacing,
                  lastChildLayoutTypeBuilder: (index) => index == items.length
                      ? LastChildLayoutType.foot
                      : LastChildLayoutType.none,
                ),
                itemCount: items.length + 1,
                itemBuilder: (context, index) {
                  if (index == items.length) {
                    if (hasNextPage) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Image.asset(
                            'assets/images/Bangboo.gif',
                            width: 80,
                            height: 80,
                          ),
                        ),
                      );
                    }
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('已经到底啦…\ [ O_X ] /'),
                      ),
                    );
                  }
                  final item = items[index];

                  final cachedDiscussion = item.cachedDiscussion;
                  if (cachedDiscussion != null) {
                    return RepaintBoundary(
                      child: _buildInsertedPostAnimation(
                        item.id,
                        KeyedSubtree(
                          key: ValueKey(item.id),
                          child: _buildCard(context, item, cachedDiscussion),
                        ),
                      ),
                    );
                  }

                  return RepaintBoundary(
                    child: _buildInsertedPostAnimation(
                      item.id,
                      FutureBuilder(
                        key: ValueKey(item.id),
                        future: item.discussion,
                        builder: (context, snaphost) {
                          if (snaphost.hasData) {
                            return _buildCard(context, item, snaphost.data!);
                          }
                          if (snaphost.hasError) {
                            return Card(
                              clipBehavior: Clip.antiAlias,
                              color: const Color(0xff222222),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(24),
                                  topRight: Radius.circular(24),
                                  bottomLeft: Radius.circular(24),
                                ),
                              ),
                              child: AspectRatio(
                                aspectRatio: 5 / 6,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Center(
                                      child:
                                          SelectableText('${snaphost.error}')),
                                ),
                              ),
                            );
                          }
                          if (snaphost.connectionState ==
                              ConnectionState.done) {
                            return Card(
                              clipBehavior: Clip.antiAlias,
                              color: const Color(0xff222222),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(24),
                                  topRight: Radius.circular(24),
                                  bottomLeft: Radius.circular(24),
                                ),
                              ),
                              child: InkWell(
                                splashColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                                onTap: () => launchUrlString(item.url),
                                child: const AspectRatio(
                                  aspectRatio: 5 / 6,
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(child: Text('帖子已删除')),
                                  ),
                                ),
                              ),
                            );
                          }
                          return const DiscussionCardSkeleton();
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );

        if (!isCompact) {
          return SmoothScroll(
            controller: scrollController,
            child: DraggableScrollbar(
              controller: scrollController,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  scrollbars: false,
                ),
                child: child,
              ),
            ),
          );
        }
        return child;
      },
    );
  }

  void _scheduleWebCoverPrecaching(List<HDataModel> items) {
    if (!kIsWeb || items.isEmpty) return;

    final visibleItems = items.take(6).toList(growable: false);
    final signature = visibleItems.map((item) => item.id).join('|');
    if (signature.isEmpty || signature == _lastPrecachingSignature) {
      return;
    }

    _lastPrecachingSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      for (final item in visibleItems) {
        final discussion = item.cachedDiscussion;
        if (discussion == null) continue;

        final coverUrl = discussion.coverImages.isNotEmpty
            ? discussion.coverImages.first.url
            : discussion.cover;
        if (coverUrl == null || coverUrl.trim().isEmpty) continue;

        try {
          await precacheImage(NetworkImage(coverUrl.trim()), context);
        } catch (_) {
          // Best-effort warm up for Web image cache.
        }
      }
    });
  }
}
