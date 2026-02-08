import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:url_launcher/url_launcher_string.dart';

class ReportDiscussionComment extends StatelessWidget {
  const ReportDiscussionComment({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Column(
        children: [
          for (final MapEntry(:key, :value) in c.report.entries) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: '被举报的讨论：'),
                    TextSpan(
                      text: '#$key',
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => launchUrlString(
                              'https://github.com/share121/inter-knot/discussions/$key',
                            ),
                      style: TextStyle(
                        decoration: TextDecoration.underline,
                        color: Theme.of(context).colorScheme.primary,
                        decorationColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const TextSpan(text: '\n'),
                    TextSpan(
                      text: '共 ${value.length} 次举报',
                    ),
                  ],
                ),
              ),
              subtitle: Column(
                children: [
                  for (final (index, comment) in value.indexed)
                    ListTile(
                      minVerticalPadding: 0,
                      title: Row(
                        children: [
                          Flexible(
                            child: InkWell(
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              onTap: () => launchUrlString(comment.url),
                              child: Text(comment.login),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        children: [
                          SelectionArea(
                            child: HtmlWidget(comment.bodyHTML),
                          ),
                          if (index != value.length - 1) const Divider(),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const Divider(),
          ],
        ],
      );
    });
  }
}
