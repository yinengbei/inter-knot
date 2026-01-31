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
              title: Text('Like'.tr),
              onTap: () => Get.to(() => const LikedPage()),
              subtitle: Text(
                'A total of @count items'
                    .trParams({'count': c.bookmarks.length.toString()}),
              ),
            ),
          ),
          Obx(
            () => ListTile(
              leading: const Icon(Icons.history),
              title: Text('History'.tr),
              onTap: () => Get.to(() => const HistoryPage()),
              subtitle: Text(
                'A total of @count items'
                    .trParams({'count': c.history.length.toString()}),
              ),
            ),
          ),
          Obx(() {
            if (c.isLogin()) {
              return ListTile(
                onTap: () async {
                  await c.setToken('');
                  c.isLogin(false);
                  Get.rawSnackbar(message: '已退出登录状态'.tr);
                },
                title: Text('退出登录'.tr),
                leading: const Icon(Icons.logout),
              );
            } else {
              return ListTile(
                onTap: () => Get.to(() => const LoginPage()),
                title: Text('Login'.tr),
                leading: const Icon(Icons.login),
              );
            }
          }),
        ],
      ),
    );
  }
}
