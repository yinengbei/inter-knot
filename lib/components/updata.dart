import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/copy_text.dart';
import 'package:inter_knot/models/release.dart';
import 'package:url_launcher/url_launcher_string.dart';

class Updata extends StatefulWidget {
  const Updata({
    super.key,
    required this.newFullVer,
    required this.curFullVer,
    required this.mustUpdate,
    required this.descriptionHTML,
    required this.release,
  });

  final String newFullVer;
  final String curFullVer;
  final String descriptionHTML;
  final bool mustUpdate;
  final ReleaseModel release;

  @override
  State<Updata> createState() => _UpdataState();
}

const f = [
  'gh.llkk.cc',
  'github.moeyy.xyz',
  'mirror.ghproxy.com',
  'ghproxy.net',
  'gh.ddlc.top',
];

class _UpdataState extends State<Updata> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('有新版本可用'),
      content: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ListTile(
                    onTap: () => copyText(widget.curFullVer),
                    title: const Text('当前版本'),
                    subtitle: Text(widget.curFullVer),
                  ),
                  ListTile(
                    onTap: () => copyText(widget.newFullVer),
                    title: const Text('最新版本'),
                    subtitle: Text(widget.newFullVer),
                  ),
                  ListTile(
                    onTap: () {},
                    title: const Text('更新内容'),
                    subtitle: widget.descriptionHTML.trim().isEmpty
                        ? const Text('空')
                        : HtmlWidget(widget.descriptionHTML),
                  ),
                  const Divider(),
                  for (final item in widget.release.releaseAssets)
                    ListTile(
                      title: Text(item.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '更新时间：${item.updatedAt.toLocal()}',
                          ),
                          Text(
                            '大小：${item.size} 字节',
                          ),
                          Text(
                            '下载次数：${item.downloadCount}',
                          ),
                        ],
                      ),
                      onTap: () =>
                          launchUrlString(c.accelerator() + item.downloadUrl),
                    ),
                ],
              ),
            ),
          ),
          const ListTile(title: Text('加速源')),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Obx(
              // ignore: prefer_const_constructors - groupValue/onChanged are not const
              () => RadioGroup<String>(
                groupValue: c.accelerator(),
                onChanged: (String? v) {
                  if (v != null) c.accelerator(v);
                },
                // Row cannot be const due to for-loop children
                child: Row(
                  children: [
                    const Column(
                      children: [
                        Radio<String>(value: ''),
                        Text('Github'),
                      ],
                    ),
                    for (final e in f) ...[
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          Radio<String>(value: 'https://$e/'),
                          Text(e),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (!widget.mustUpdate)
          TextButton(
            style: const ButtonStyle(
              overlayColor: WidgetStatePropertyAll(Colors.transparent),
            ),
            onPressed: () => Get.back(),
            child: const Text('确定'),
          ),
      ],
    );
  }
}
