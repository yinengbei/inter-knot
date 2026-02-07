import 'package:flutter/material.dart';
import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/helpers/copy_text.dart';
import 'package:inter_knot/helpers/num2dur.dart';
import 'package:url_launcher/url_launcher_string.dart';

class FeedbackBtn extends StatelessWidget {
  const FeedbackBtn(this.error, {super.key});

  final String error;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: const ButtonStyle(
        overlayColor: WidgetStatePropertyAll(Colors.transparent),
      ),
      onPressed: () async {
        Future.delayed(3.s).then((_) => launchUrlString(issuesLink));
        await copyText(
          error,
          title: '错误提示已复制',
          msg: '3 秒后自动打开 GitHub Issues 页面',
        );
      },
      child: const Text('反馈'),
    );
  }
}
