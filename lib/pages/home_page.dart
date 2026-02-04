import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/pages/history_page.dart';
import 'package:inter_knot/pages/liked_page.dart';
import 'package:inter_knot/pages/login_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Obx(
            () => ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('喜欢'),
              onTap: () => Get.to(() => const LikedPage()),
              subtitle: Text(
                '共 ${c.bookmarks.length} 项',
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
                onTap: () => Get.to(() => const LoginPage()),
                title: const Text('登录'),
                leading: const Icon(Icons.login),
              );
            }
          }),
        ],
      ),
    );
  }
}
