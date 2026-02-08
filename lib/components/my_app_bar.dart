import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/avatar.dart';
import 'package:inter_knot/components/my_tab.dart';
import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/gen/assets.gen.dart';

class MyAppBar extends StatelessWidget {
  const MyAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 640;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: isCompact ? width : max(width, 640),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.black,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xff212121),
                      Color(0xff141414),
                      Color(0xff181818),
                    ],
                    stops: [0, 0.9, 1.0],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(maxRadius),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Obx(() {
                      final canUpload = c.isLogin.value;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Avatar(
                            c.user()?.avatar,
                            onTap: canUpload ? c.pickAndUploadAvatar : null,
                          ),
                          if (c.isUploadingAvatar.value)
                            const Positioned.fill(
                              child: ColoredBox(
                                color: Color(0x66000000),
                                child: Center(
                                  child: SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    }),
                    const SizedBox(width: 4),
                    Obx(() {
                      return Text(
                        c.user()?.name ?? '未登录',
                        style: const TextStyle(
                          fontSize: 18,
                          height: 1,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const Spacer(),
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
                            c.animateToPage(0);
                          },
                        ),
                        MyTab(
                          text: '我的',
                          isSelected: page == 1,
                          onTap: () => c.animateToPage(1),
                        ),
                      ],
                    );
                  }),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
