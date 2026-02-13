import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 8),
                  Image.asset(
                    'assets/images/zzzicon.png',
                    width: 48,
                    height: 48,
                    filterQuality: FilterQuality.medium,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Inter-Knot',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1.0,
                    ),
                  ),
                ],
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
                            c.animateToPage(0, animate: false);
                          },
                        ),
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
            ],
          ),
        ),
      ),
    );
  }
}
