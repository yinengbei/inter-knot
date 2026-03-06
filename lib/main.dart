import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/components/fade_indexed_stack.dart';
import 'package:inter_knot/components/my_app_bar.dart';
import 'package:inter_knot/components/update_dialog.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/app_scroll_behavior.dart';
import 'package:inter_knot/helpers/toast.dart';
import 'package:inter_knot/pages/create_discussion_page.dart';
import 'package:inter_knot/pages/home_page.dart';
import 'package:inter_knot/pages/notification_page.dart';
import 'package:inter_knot/pages/search_page.dart';
import 'package:inter_knot/services/captcha_service.dart';
import 'package:inter_knot/services/update_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  Get.put(AuthApi());
  Get.put(Api());
  await Get.putAsync(() => CaptchaService().init());
  Get.put(Controller());
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'InterKnot',
      navigatorKey: Get.key,
      scrollBehavior: AppScrollBehavior(),
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'ZhCn',
        fontFamilyFallback: const ['ZhCn', 'sans-serif'],
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        dividerColor: const Color(0xff2D2D2D),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xffD7FF00),
          primary: const Color(0xffD7FF00),
          secondary: const Color(0xff00E5FF), // 辅助青色
          surface: const Color(0xff121212),
          onSurface: Colors.white,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xff0A0A0A), // 更深的背景
        textTheme: const TextTheme(
          titleMedium: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900, // 更粗的字体符合 ZZZ 风格
            letterSpacing: 1.2,
          ),
          bodyMedium: TextStyle(fontSize: 15, color: Color(0xffE0E0E0)),
          labelMedium: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xffD7FF00),
          ),
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('zh', 'TC'),
        Locale('en'),
      ],
      home: const MyHomePage(),
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) {
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static DateTime? _lastPressedAt;
  final controller = Get.find<Controller>();

  @override
  void initState() {
    super.initState();
    // Auto check for updates on app startup (Android only)
    _checkForUpdatesOnStartup();
  }

  Future<void> _checkForUpdatesOnStartup() async {
    // Only check on Android platform
    if (!kIsWeb && Platform.isAndroid) {
      // Delay to avoid blocking app startup
      await Future.delayed(const Duration(seconds: 2));
      
      try {
        final updateInfo = await UpdateService.checkForUpdate();
        if (updateInfo != null && mounted) {
          // Show update dialog
          showUpdateDialog(context, updateInfo);
        }
      } catch (e) {
        // Silently fail, don't disturb user
        debugPrint('Auto update check failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine layout based on screen width
    // Use 640 logical pixels as the breakpoint for mobile layout
    final isCompact = MediaQuery.of(context).size.width < 640;

    if (isCompact) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          
          // 如果在我的页面，跳转到首页
          if (controller.selectedIndex.value == 1) {
            controller.animateToPage(0, animate: false);
            return;
          }
          
          // 如果在首页，显示"再按一次退出"提示
          if (controller.selectedIndex.value == 0) {
            final now = DateTime.now();
            if (_lastPressedAt == null || 
                now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
              _lastPressedAt = now;
              showToast('再按一次退出绳网', duration: const Duration(seconds: 2));
            } else {
              // 2秒内再次按下，退出应用
              SystemNavigator.pop();
            }
          }
        },
        child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: const Color(0xff121212),
        body: Column(
          children: [
            const MyAppBar(),
            Expanded(
              child: PageView(
                physics: const NeverScrollableScrollPhysics(), // Disable swipe gesture
                controller: controller.pageController,
                onPageChanged: (index) =>
                    controller.selectedIndex.value = index,
                children: const [
                  SearchPage(),
                  HomePage(),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: Obx(
          () => Container(
            height: 58,
            decoration: const BoxDecoration(
              color: Color(0xff1A1A1A),
              border: Border(
                top: BorderSide(
                  color: Colors.white12,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BottomNavItem(
                  isSelected: controller.selectedIndex.value == 0,
                  icon: Icons.explore_outlined,
                  activeIcon: Icons.explore,
                  label: '推送',
                  onTap: () => controller.animateToPage(0, animate: false),
                  onDoubleTap: () {
                    // Double tap to refresh posts
                    if (controller.selectedIndex.value == 0) {
                      controller.refreshSearchData();
                      showToast('正在刷新帖子...', duration: const Duration(seconds: 1));
                    }
                  },
                ),
                Center(
                  child: _buildCreateButton(context),
                ),
                _BottomNavItem(
                  isSelected: controller.selectedIndex.value == 1,
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: '我的',
                  onTap: () => controller.animateToPage(1, animate: false),
                ),
              ],
            ),
          ),
        ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xff121212),
      body: Column(
        children: [
          const MyAppBar(),
          Expanded(
            child: Obx(
              () => FadeIndexedStack(
                index: controller.selectedIndex.value,
                duration: Duration.zero,
                children: [
                  const SearchPage(),
                  const HomePage(),
                  NotificationPage(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton(BuildContext context) {
    return _AnimatedCreateButton(
      onTap: () async {
        if (await controller.ensureLogin()) {
          CreateDiscussionPage.show(context);
        }
      },
    );
  }
}

class _BottomNavItem extends StatefulWidget {
  final bool isSelected;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;

  const _BottomNavItem({
    required this.isSelected,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
    this.onDoubleTap,
  });

  @override
  State<_BottomNavItem> createState() => _BottomNavItemState();
}

class _BottomNavItemState extends State<_BottomNavItem> {
  DateTime? _lastTapTime;

  void _handleTap() {
    final now = DateTime.now();
    
    if (_lastTapTime != null && 
        now.difference(_lastTapTime!) < const Duration(milliseconds: 300)) {
      // Double tap detected
      if (widget.onDoubleTap != null) {
        widget.onDoubleTap!();
      }
      _lastTapTime = null; // Reset to prevent triple tap
    } else {
      // Single tap
      _lastTapTime = now;
      widget.onTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: AnimatedScale(
          scale: widget.isSelected ? 1.20 : 1.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.isSelected ? widget.activeIcon : widget.icon,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(height: 2),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedCreateButton extends StatefulWidget {
  final VoidCallback onTap;

  const _AnimatedCreateButton({required this.onTap});

  @override
  State<_AnimatedCreateButton> createState() => _AnimatedCreateButtonState();
}

class _AnimatedCreateButtonState extends State<_AnimatedCreateButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _colorController;
  late final Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();

    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _colorAnimation = ColorTween(
      begin: const Color(0xfffbfe00),
      end: const Color(0xffdcfe00),
    ).animate(CurvedAnimation(
      parent: _colorController,
      curve: Curves.linear,
    ));
  }

  @override
  void dispose() {
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Material(
          color: _colorAnimation.value ?? const Color(0xffFBC02D),
          shape: const CircleBorder(),
          child: InkWell(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            customBorder: const CircleBorder(),
            onTap: widget.onTap,
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.add, color: Colors.black, size: 24),
            ),
          ),
        );
      },
    );
  }
}
