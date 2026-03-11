import 'package:flutter/material.dart';
import 'package:inter_knot/helpers/deferred_loader.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/h_data.dart';
import 'package:inter_knot/pages/create_discussion_page.dart'
    deferred as create_discussion_page;
import 'package:inter_knot/pages/discussion_page.dart'
    deferred as discussion_page;
import 'package:inter_knot/pages/notification_page.dart'
    deferred as notification_page;

Future<bool?> showCreateDiscussionPage(
  BuildContext context, {
  DiscussionModel? discussion,
}) {
  return showDeferredZZZDialog<bool>(
    context: context,
    loadLibrary: create_discussion_page.loadLibrary,
    loadingLabel: 'Loading editor...',
    pageBuilder: (context) =>
        create_discussion_page.CreateDiscussionPage(discussion: discussion),
  );
}

Future<bool?> showDiscussionPageDialog(
  BuildContext context, {
  required DiscussionModel discussion,
  required HDataModel hData,
  bool reorderHistoryOnOpen = true,
}) {
  return showDeferredZZZDialog<bool>(
    context: context,
    loadLibrary: discussion_page.loadLibrary,
    loadingLabel: 'Loading discussion...',
    pageBuilder: (context) => discussion_page.DiscussionPage(
      discussion: discussion,
      hData: hData,
      reorderHistoryOnOpen: reorderHistoryOnOpen,
    ),
  );
}

Future<void> pushNotificationPage(BuildContext context) {
  return navigateWithDeferredSlideTransition<void>(
    context: context,
    loadLibrary: notification_page.loadLibrary,
    loadingLabel: 'Loading notifications...',
    routeName: '/notifications',
    pageBuilder: (context) => notification_page.NotificationPage(),
  );
}
