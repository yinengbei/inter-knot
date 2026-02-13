import 'package:flutter/material.dart';
import 'package:inter_knot/components/discussion_card.dart';
import 'package:get/get.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/num2dur.dart';
import 'package:inter_knot/helpers/smooth_scroll.dart';
import 'package:inter_knot/models/h_data.dart';
import 'package:inter_knot/pages/discussion_page.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

class DiscussionGrid extends StatefulWidget {
  const DiscussionGrid({
    super.key,
    required this.list,
    required this.hasNextPage,
    this.fetchData,
  });

  final Set<HDataModel> list;
  final bool hasNextPage;
  final void Function()? fetchData;

  @override
  State<DiscussionGrid> createState() => _DiscussionGridState();
}

class _DiscussionGridState extends State<DiscussionGrid> {
  final scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!widget.hasNextPage) return;
    final maxScroll = scrollController.position.maxScrollExtent;
    final currentScroll = scrollController.position.pixels;
    if (maxScroll - currentScroll <= 100) {
      widget.fetchData?.call();
    }
  }

  @override
  void dispose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.list;
    final fetchData = widget.fetchData;
    final hasNextPage = widget.hasNextPage;
    if (list.isEmpty) {
      return Center(
        child: Obx(() {
          final isSearching = Get.find<Controller>().isSearching.value;
          if (isSearching) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/Bangboo.gif',
                  width: 120,
                  height: 120,
                ),
                const SizedBox(height: 16),
                const Text(
                  '正在搜索...',
                  style: TextStyle(
                    color: Color(0xff808080),
                    fontSize: 16,
                  ),
                ),
              ],
            );
          }
          return const Text(
            '暂无相关帖子',
            style: TextStyle(
              color: Color.fromARGB(255, 233, 233, 233),
              fontSize: 16,
            ),
          );
        }),
      );
    }
    return LayoutBuilder(
      builder: (context, con) {
        final isCompact = MediaQuery.of(context).size.width < 640;
        final child = Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1450),
            child: WaterfallFlow.builder(
              controller: scrollController,
              physics: !isCompact
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(4),
              gridDelegate: SliverWaterfallFlowDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 275,
                mainAxisSpacing: 2,
                crossAxisSpacing: 1,
                lastChildLayoutTypeBuilder: (index) => index == list.length
                    ? LastChildLayoutType.foot
                    : LastChildLayoutType.none,
                viewportBuilder: (firstIndex, lastIndex) {
                  if (lastIndex == list.length) fetchData?.call();
                },
              ),
              itemCount: list.length + 1,
              itemBuilder: (context, index) {
                if (index == list.length) {
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
                      child: Text('没有更多数据了'),
                    ),
                  );
                }
                final item = list.elementAt(index);
                return FutureBuilder(
                  future: item.discussion,
                  builder: (context, snaphost) {
                    if (snaphost.hasData) {
                      return DiscussionCard(
                        discussion: snaphost.data!,
                        hData: item,
                        onTap: () async {
                          final result = await showGeneralDialog(
                            context: context,
                            barrierDismissible: true,
                            barrierLabel: '取消',
                            pageBuilder:
                                (context, animation, secondaryAnimation) {
                              return DiscussionPage(
                                discussion: snaphost.data!,
                                hData: item,
                              );
                            },
                            transitionDuration: 300.ms,
                            transitionBuilder: (context, animaton1,
                                secondaryAnimation, child) {
                              return AnimatedBuilder(
                                animation: animaton1,
                                builder: (context, child) {
                                  final curve = Curves.easeOutQuart;
                                  final double value = animaton1.value;
                                  final double curvedValue =
                                      curve.transform(value);

                                  Offset translation;
                                  if (animaton1.status ==
                                      AnimationStatus.reverse) {
                                    translation =
                                        Offset(-0.05 * (1 - curvedValue), 0.0);
                                  } else {
                                    translation =
                                        Offset(0.05 * (1 - curvedValue), 0.0);
                                  }

                                  return Opacity(
                                    opacity: curvedValue,
                                    child: FractionalTranslation(
                                      translation: translation,
                                      child: child,
                                    ),
                                  );
                                },
                                child: RepaintBoundary(child: child),
                              );
                            },
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
                    if (snaphost.hasError) {
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        color: const Color(0xff222222),
                        child: AspectRatio(
                          aspectRatio: 5 / 6,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                                child: SelectableText('${snaphost.error}')),
                          ),
                        ),
                      );
                    }
                    if (snaphost.connectionState == ConnectionState.done) {
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        color: const Color(0xff222222),
                        child: InkWell(
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          onTap: () => launchUrlString(item.url),
                          child: const AspectRatio(
                            aspectRatio: 5 / 6,
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: Text('讨论已删除')),
                            ),
                          ),
                        ),
                      );
                    }
                    return const DiscussionCardSkeleton();
                  },
                );
              },
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
}
