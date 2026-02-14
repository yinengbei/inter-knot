import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/discussions_grid.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/throttle.dart';
import 'package:inter_knot/pages/create_discussion_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with AutomaticKeepAliveClientMixin {
  final c = Get.find<Controller>();

  final keyboardVisibilityController = KeyboardVisibilityController();
  late final keyboardSubscription =
      keyboardVisibilityController.onChange.listen((visible) {
    if (!visible) FocusManager.instance.primaryFocus?.unfocus();
  });

  Timer? _debounce;

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(seconds: 1), () {
      c.searchQuery(query);
    });
  }

  @override
  void dispose() {
    keyboardSubscription.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  late final fetchData = retryThrottle(
    c.searchData,
    const Duration(milliseconds: 500),
  );

  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 640;

    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/zzz.webp',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
        Column(
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SearchBar(
                  controller: c.searchController,
                  onChanged: _onSearchChanged,
                  onSubmitted: c.searchQuery.call,
                  backgroundColor:
                      const WidgetStatePropertyAll(Color(0xff1E1E1E)),
                  leading: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.search, color: Color(0xffB0B0B0)),
                  ),
                  hintText: '搜索',
                  hintStyle: const WidgetStatePropertyAll(
                    TextStyle(color: Color(0xff808080)),
                  ),
                  textStyle: const WidgetStatePropertyAll(
                    TextStyle(color: Color(0xffE0E0E0)),
                  ),
                  side: WidgetStatePropertyAll(
                    BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Stack(
                children: [
                  isCompact
                      ? RefreshIndicator(
                          onRefresh: () async {
                            await c.refreshSearchData();
                          },
                          child: Obx(() {
                            return DiscussionGrid(
                              list: c.searchResult(),
                              hasNextPage: c.searchHasNextPage(),
                              fetchData: fetchData,
                              controller: _scrollController,
                            );
                          }),
                        )
                      : Obx(() {
                          return DiscussionGrid(
                            list: c.searchResult(),
                            hasNextPage: c.searchHasNextPage(),
                            fetchData: fetchData,
                            controller: _scrollController,
                          );
                        }),
                  Positioned(
                    top: 16,
                    left: 0,
                    right: 0,
                    child: Obx(() {
                      final count = c.newPostCount.value;
                      final hasChange = c.hasContentChange.value;

                      if (count == 0 && !hasChange)
                        return const SizedBox.shrink();

                      String message = '帖子列表有更新';
                      if (count > 0) {
                        message = '有 $count 个新帖子';
                      }

                      return Center(
                        child: Material(
                          color: const Color(0xffD7FF00),
                          borderRadius: BorderRadius.circular(20),
                          elevation: 4,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () async {
                              await c.showNewPosts();
                              // Ensure layout is built before scrolling
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (_scrollController.hasClients) {
                                  _scrollController.animateTo(
                                    0,
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.easeOutQuart,
                                  );
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.arrow_upward,
                                    size: 16,
                                    color: Colors.black,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    message,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!isCompact)
          Positioned(
            bottom: 24,
            right: 24,
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xff1A1A1A).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: const Color(0xff333333),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Refresh Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      borderRadius: BorderRadius.circular(28),
                      onTap: () {
                        c.refreshSearchData();
                      },
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 1,
                    height: 24,
                    color: const Color(0xff333333),
                  ),
                  const SizedBox(width: 4),
                  // Create Discussion Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      borderRadius: BorderRadius.circular(28),
                      onTap: () async {
                        if (await c.ensureLogin()) {
                          CreateDiscussionPage.show(context);
                        }
                      },
                      child: Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xffFBC02D), // Yellow accent
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.black,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              '发布委托',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
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
  }

  @override
  bool get wantKeepAlive => true;
}
