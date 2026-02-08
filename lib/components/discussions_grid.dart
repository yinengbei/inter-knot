import 'package:flutter/material.dart';
import 'package:inter_knot/components/discussion_card.dart';
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
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.list;
    final fetchData = widget.fetchData;
    final hasNextPage = widget.hasNextPage;
    if (list.isEmpty) return const Center(child: Text('空'));
    return LayoutBuilder(
      builder: (context, con) {
        final isCompact = MediaQuery.of(context).size.width < 640;
        final child = WaterfallFlow.builder(
          controller: scrollController,
          physics: !isCompact
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(4),
          gridDelegate: SliverWaterfallFlowDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 275,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
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
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(),
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
                    onTap: () {
                      showGeneralDialog(
                        context: context,
                        barrierDismissible: true,
                        barrierLabel: '取消',
                        pageBuilder: (context, animation, secondaryAnimation) {
                          return DiscussionPage(
                            discussion: snaphost.data!,
                            hData: item,
                          );
                        },
                        transitionDuration: 300.ms,
                        transitionBuilder:
                            (context, animaton1, secondaryAnimation, child) {
                          return FadeTransition(
                            opacity: animaton1,
                            child: SlideTransition(
                              position: Tween(
                                begin: const Offset(0.1, 0.0),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: animaton1,
                                  curve: Curves.ease,
                                ),
                              ),
                              child: child,
                            ),
                          );
                        },
                      );
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
                        child:
                            Center(child: SelectableText('${snaphost.error}')),
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
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
        if (!isCompact) {
          return SmoothScroll(
            controller: scrollController,
            child: child,
          );
        }
        return child;
      },
    );
  }
}
