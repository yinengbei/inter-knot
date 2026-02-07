import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/components/my_app_bar.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/app_scroll_behavior.dart';
import 'package:inter_knot/pages/create_discussion_page.dart';
import 'package:inter_knot/pages/home_page.dart';
import 'package:inter_knot/pages/login_page.dart';
import 'package:inter_knot/pages/search_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  Get.put(AuthApi());
  Get.put(Api());
  Get.put(Controller());
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Inter-Knot',
      scrollBehavior: AppScrollBehavior(),
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'ZhCn',
        fontFamilyFallback: const ['ZhCn', 'sans-serif'],
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
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
    );
  }
}

class MyHomePage extends GetView<Controller> {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Determine layout based on screen width
    // Use 640 logical pixels as the breakpoint for mobile layout
    final isCompact = MediaQuery.of(context).size.width < 640;

    if (isCompact) {
      return Scaffold(
        backgroundColor: const Color(0xff121212),
        body: Column(
          children: [
            const MyAppBar(),
            const SizedBox(height: 16),
            Expanded(
              child: PageView(
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
            color: const Color(0xff1A1A1A),
            height: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: InkWell(
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    onTap: () => controller.animateToPage(0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          controller.selectedIndex.value == 0
                              ? Icons.explore
                              : Icons.explore_outlined,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '推送',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Material(
                    color: const Color(0xffFBC02D),
                    shape: const CircleBorder(),
                    child: InkWell(
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      customBorder: const CircleBorder(),
                      onTap: () {
                        if (controller.isLogin.value) {
                          Get.to(() => const CreateDiscussionPage());
                        } else {
                          Get.to(() => const LoginPage());
                        }
                      },
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(Icons.add, color: Colors.black),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    onTap: () => controller.animateToPage(1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          controller.selectedIndex.value == 1
                              ? Icons.person
                              : Icons.person_outline,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '我的',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
          const SizedBox(height: 16),
          Expanded(
            child: PageView(
              controller: controller.pageController,
              children: const [
                SearchPage(),
                HomePage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
