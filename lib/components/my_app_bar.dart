import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/my_tab.dart';
import 'package:inter_knot/gen/assets.gen.dart';
import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/components/avatar.dart';
import 'package:inter_knot/helpers/deferred_routes.dart';

class MyAppBar extends StatefulWidget {
  const MyAppBar({super.key});

  @override
  State<MyAppBar> createState() => _MyAppBarState();
}

class _MyAppBarState extends State<MyAppBar> {
  Timer? _debounce;

  Future<void> navigateWithSlideTransition(BuildContext context) {
    return pushNotificationPage(context);
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(seconds: 1), () {
      c.searchQuery(query);
    });
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 640;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: isCompact ? width : max(width, 640),
        child: Container(
          padding:
              EdgeInsets.symmetric(horizontal: 12, vertical: isCompact ? 4 : 8),
          decoration: const BoxDecoration(
            color: Colors.black,
            border: Border(
              bottom: BorderSide(
                color: Colors.white12,
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 8),
                    if (isCompact)
                      Obx(() {
                        final user = c.user.value;
                        return Avatar(
                          user?.avatar,
                          size: 36,
                          onTap: () => c.animateToPage(1, animate: false),
                        );
                      })
                    else
                      SvgPicture.asset(
                        'assets/images/zzzicon.svg',
                        width: 48,
                        height: 48,
                        fit: BoxFit.contain,
                      ),
                    if (!isCompact) ...[
                      const SizedBox(width: 12),
                      const Text(
                        'INTER-KNOT',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -1.0,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: 12),
                // 新增：搜索栏
                Expanded(
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: isCompact ? 8 : 16),
                    child: Align(
                      alignment: Alignment.center,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: 700,
                          maxHeight: isCompact ? 36 : 48,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: SearchBar(
                          controller: c.searchController,
                          onChanged: _onSearchChanged,
                          onSubmitted: c.searchQuery.call,
                          constraints: BoxConstraints(
                            minHeight: isCompact ? 36 : 48,
                            maxHeight: isCompact ? 36 : 48,
                          ),
                          padding: WidgetStatePropertyAll(
                            EdgeInsets.symmetric(
                                horizontal: isCompact ? 8 : 16),
                          ),
                          backgroundColor:
                              const WidgetStatePropertyAll(Color(0xff1E1E1E)),
                          leading: Padding(
                            padding: EdgeInsets.only(left: isCompact ? 4 : 8),
                            child: Icon(
                              Icons.search,
                              color: const Color(0xffB0B0B0),
                              size: isCompact ? 20 : 24,
                            ),
                          ),
                          hintText: '搜索',
                          hintStyle: WidgetStatePropertyAll(
                            TextStyle(
                              color: const Color(0xff808080),
                              fontSize: isCompact ? 14 : null,
                            ),
                          ),
                          textStyle: WidgetStatePropertyAll(
                            TextStyle(
                              color: const Color(0xffE0E0E0),
                              fontSize: isCompact ? 14 : null,
                            ),
                          ),
                          side: WidgetStatePropertyAll(
                            BorderSide(
                              color: Colors.white.withValues(alpha: 0.1),
                              width: 1,
                            ),
                          ),
                          trailing: [
                            AnimatedBuilder(
                              animation: c.searchController,
                              builder: (context, _) {
                                final hasText =
                                    c.searchController.text.trim().isNotEmpty;
                                if (!hasText) return const SizedBox.shrink();

                                return IconButton(
                                  tooltip: '清除',
                                  onPressed: () {
                                    c.searchController.clear();
                                    c.searchQuery('');
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                  },
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: const Color(0xffB0B0B0),
                                    size: isCompact ? 18 : 20,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (!isCompact)
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xff313131),
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(maxRadius),
                      image: DecorationImage(
                        image: Assets.images.tabBgPoint.provider(),
                        repeat: ImageRepeat.repeat,
                      ),
                    ),
                    child: Obx(() {
                      final page = c.curPage.value;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MyTab(
                            first: true,
                            text: '推送',
                            isSelected: page == 0,
                            onTap: () {
                              if (c.curPage() == 0) c.refreshSearchData();
                              c.animateToPage(0, animate: false);
                            },
                          ),
                          // 消息中心按钮
                          Obx(() => Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  MyTab(
                                    text: '消息',
                                    middle: true,
                                    isSelected: c.selectedIndex.value == 2,
                                    onTap: () async {
                                      if (await c.ensureLogin()) {
                                        c.animateToPage(2, animate: false);
                                      }
                                    },
                                  ),
                                  if (c.unreadNotificationCount.value > 0)
                                    Positioned(
                                      right: 18,
                                      top: 3,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.black,
                                            width: 1,
                                          ),
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 16,
                                          minHeight: 16,
                                        ),
                                        child: Text(
                                          c.unreadNotificationCount.value > 99
                                              ? '99+'
                                              : c.unreadNotificationCount.value
                                                  .toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            height: 1,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                ],
                              )),
                          MyTab(
                            text: '我的',
                            last: true,
                            isSelected: page == 1,
                            onTap: () => c.animateToPage(1, animate: false),
                          ),
                        ],
                      );
                    }),
                  ),
                // 移动端：右侧显示消息中心图标按钮
                if (isCompact) ...[
                  const SizedBox(width: 8),
                  Obx(() => IconButton(
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(
                              Icons.notifications_outlined,
                              color: Colors.white,
                              size: 24,
                            ),
                            if (c.unreadNotificationCount.value > 0)
                              Positioned(
                                right: -5,
                                top: -10,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 1.5,
                                    ),
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 18,
                                    minHeight: 18,
                                  ),
                                  child: Text(
                                    c.unreadNotificationCount.value > 99
                                        ? '99+'
                                        : c.unreadNotificationCount.value
                                            .toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        onPressed: () async {
                          if (await c.ensureLogin()) {
                            // 移动端：使用平滑的页面过渡动画
                            await navigateWithSlideTransition(
                              context,
                            );
                            c.refreshUnreadNotificationCount();
                          }
                        },
                        tooltip: '消息中心',
                      )),
                  const SizedBox(width: 4),
                ] else
                  const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
