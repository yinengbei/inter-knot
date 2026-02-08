import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/discussions_grid.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/throttle.dart';
import 'package:inter_knot/pages/create_discussion_page.dart';
import 'package:inter_knot/pages/login_page.dart';

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

  @override
  void dispose() {
    keyboardSubscription.cancel();
    super.dispose();
  }

  late final fetchData = retryThrottle(c.searchData);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 640;

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SearchBar(
                controller: c.searchController,
                onSubmitted: c.searchQuery.call,
                backgroundColor:
                    const WidgetStatePropertyAll(Color(0xff222222)),
                leading: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.search),
                ),
                hintText: '搜索',
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: isCompact
                  ? RefreshIndicator(
                      onRefresh: () async {
                        await c.refreshSearchData();
                      },
                      child: Obx(() {
                        return DiscussionGrid(
                          list: c.searchResult(),
                          hasNextPage: c.searchHasNextPage(),
                          fetchData: fetchData,
                        );
                      }),
                    )
                  : Obx(() {
                      return DiscussionGrid(
                        list: c.searchResult(),
                        hasNextPage: c.searchHasNextPage(),
                        fetchData: fetchData,
                      );
                    }),
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
                      onTap: () {
                        if (c.isLogin.value) {
                          Get.to(() => const CreateDiscussionPage());
                        } else {
                          Get.to(() => const LoginPage());
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
