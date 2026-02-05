import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/components/my_app_bar.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/pages/home_page.dart';
import 'package:inter_knot/pages/search_page.dart';

Future<void> main() async {
  await GetStorage.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(AuthApi());
    Get.put(Api());
    Get.put(Controller());
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    return GetMaterialApp(
      title: 'Inter-Knot',
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'ZhCn',
        fontFamilyFallback: const ['ZhCn', 'sans-serif'],
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
