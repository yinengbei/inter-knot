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

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin {
  final scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final child = Column(
      children: [
        const SizedBox(height: 16),
        Obx(
          () => Card(
            color: const Color(0xff1E1E1E),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('喜欢'),
              onTap: () => Get.to(
                () => const LikedPage(),
                routeName: '/liked',
              ),
              subtitle: Text(
                '共 ${c.bookmarks.length} 项',
                style: const TextStyle(color: Color(0xff808080)),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            ),
          ),
        ),
        Obx(
          () => Card(
            color: const Color(0xff1E1E1E),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.history),
              title: const Text('历史记录'),
              onTap: () => Get.to(
                () => const HistoryPage(),
                routeName: '/history',
              ),
              subtitle: Text(
                '共 ${c.history.length} 项',
                style: const TextStyle(color: Color(0xff808080)),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            ),
          ),
        ),
        Obx(() {
          if (c.isLogin()) {
            return Card(
              color: const Color(0xff1E1E1E),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                onTap: () async {
                  await c.setToken('');
                  c.isLogin(false);
                  Get.rawSnackbar(message: '已退出登录');
                },
                title: const Text('退出登录'),
                leading: const Icon(Icons.logout),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              ),
            );
          } else {
            return Card(
              color: const Color(0xff1E1E1E),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
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
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              ),
            );
          }
        }),
      ],
    );

    // Desktop/expanded layout uses SmoothScroll with DraggableScrollbar
    // Compact layout uses standard scrolling
    final isCompact = MediaQuery.of(context).size.width < 640;

    if (!isCompact) {
      return Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/pc-page-bg.png',
              fit: BoxFit.cover,
            ),
          ),
          SmoothScroll(
            controller: scrollController,
            child: DraggableScrollbar(
              controller: scrollController,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  scrollbars: false,
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const NeverScrollableScrollPhysics(),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/pc-page-bg.png',
            fit: BoxFit.cover,
          ),
        ),
        SingleChildScrollView(
          controller: scrollController,
          child: child,
        ),
      ],
    );
  }
}
