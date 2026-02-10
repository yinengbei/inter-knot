import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/num2dur.dart';
import 'package:inter_knot/helpers/smooth_scroll.dart';
import 'package:inter_knot/pages/history_page.dart';
import 'package:inter_knot/pages/liked_page.dart';
import 'package:inter_knot/pages/login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final scrollController = ScrollController();

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = Column(
      children: [
        const SizedBox(height: 16),
        Obx(
          () => ListTile(
            leading: const Icon(Icons.favorite),
            title: const Text('喜欢'),
            onTap: () => Get.to(() => const LikedPage()),
            subtitle: Text(
              '共 ${c.bookmarks.length} 项',
              style: const TextStyle(color: Color(0xff808080)),
            ),
          ),
        ),
        Obx(
          () => ListTile(
            leading: const Icon(Icons.history),
            title: const Text('历史记录'),
            onTap: () => Get.to(() => const HistoryPage()),
            subtitle: Text(
              '共 ${c.history.length} 项',
              style: const TextStyle(color: Color(0xff808080)),
            ),
          ),
        ),
        Obx(() {
          if (c.isLogin()) {
            return ListTile(
              onTap: () async {
                await c.setToken('');
                c.isLogin(false);
                Get.rawSnackbar(message: '已退出登录');
              },
              title: const Text('退出登录'),
              leading: const Icon(Icons.logout),
            );
          } else {
            return ListTile(
              onTap: () {
                showGeneralDialog(
                  context: context,
                  barrierDismissible: true,
                  barrierLabel: '取消',
                  pageBuilder: (context, animation, secondaryAnimation) {
                    return const LoginPage();
                  },
                  transitionDuration: 300.ms,
                  transitionBuilder:
                      (context, animation, secondaryAnimation, child) {
                    final curvedAnimation = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutQuart,
                    );
                    return FadeTransition(
                      opacity: curvedAnimation,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0.05, 0.0),
                          end: Offset.zero,
                        ).animate(curvedAnimation),
                        child: RepaintBoundary(child: child),
                      ),
                    );
                  },
                );
              },
              title: const Text('登录'),
              leading: const Icon(Icons.login),
            );
          }
        }),
      ],
    );

    // Desktop/expanded layout uses SmoothScroll with DraggableScrollbar
    // Compact layout uses standard scrolling
    final isCompact = MediaQuery.of(context).size.width < 640;

    if (!isCompact) {
      return SmoothScroll(
        controller: scrollController,
        child: DraggableScrollbar(
          controller: scrollController,
          child: SingleChildScrollView(
            controller: scrollController,
            physics: const NeverScrollableScrollPhysics(),
            child: child,
          ),
        ),
      );
    }
    return SingleChildScrollView(
      controller: scrollController,
      child: child,
    );
  }
}
