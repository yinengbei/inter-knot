import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:inter_knot/helpers/dialog_helper.dart';
import 'package:inter_knot/helpers/page_transition_helper.dart';

class DeferredPageHost extends StatefulWidget {
  const DeferredPageHost({
    super.key,
    required this.shouldLoad,
    required this.loadLibrary,
    required this.pageBuilder,
    this.placeholder,
  });

  final bool shouldLoad;
  final Future<void> Function() loadLibrary;
  final WidgetBuilder pageBuilder;
  final Widget? placeholder;

  @override
  State<DeferredPageHost> createState() => _DeferredPageHostState();
}

class _DeferredPageHostState extends State<DeferredPageHost> {
  bool _isLoaded = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.shouldLoad) {
      _ensureLoaded();
    }
  }

  @override
  void didUpdateWidget(covariant DeferredPageHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldLoad && !_isLoaded) {
      _ensureLoaded();
    }
  }

  Future<void> _ensureLoaded() async {
    if (_isLoaded || _isLoading) return;
    _isLoading = true;
    try {
      await widget.loadLibrary();
      if (!mounted) return;
      setState(() {
        _isLoaded = true;
      });
    } finally {
      _isLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoaded) {
      return widget.pageBuilder(context);
    }

    return widget.placeholder ??
        const ColoredBox(
          color: Color(0xff121212),
          child: Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ),
        );
  }
}

Future<T?> showDeferredZZZDialog<T>({
  required BuildContext context,
  required Future<void> Function() loadLibrary,
  required WidgetBuilder pageBuilder,
  bool barrierDismissible = true,
  String loadingLabel = 'Loading...',
}) async {
  await _loadLibraryWithIndicator(
    context: context,
    loadLibrary: loadLibrary,
    loadingLabel: loadingLabel,
  );
  if (!context.mounted) return null;
  return showZZZDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    pageBuilder: pageBuilder,
  );
}

Future<T?> navigateWithDeferredSlideTransition<T>({
  required BuildContext context,
  required Future<void> Function() loadLibrary,
  required WidgetBuilder pageBuilder,
  String? routeName,
  String loadingLabel = 'Loading...',
}) async {
  await _loadLibraryWithIndicator(
    context: context,
    loadLibrary: loadLibrary,
    loadingLabel: loadingLabel,
  );
  if (!context.mounted) return null;
  return navigateWithSlideTransition<T>(
    context,
    pageBuilder(context),
    routeName: routeName,
  );
}

Future<void> _loadLibraryWithIndicator({
  required BuildContext context,
  required Future<void> Function() loadLibrary,
  required String loadingLabel,
}) async {
  if (!kIsWeb) {
    await loadLibrary();
    return;
  }

  final navigator = Navigator.of(context, rootNavigator: true);
  var indicatorVisible = false;
  Timer? indicatorTimer;

  indicatorTimer = Timer(const Duration(milliseconds: 180), () {
    if (!context.mounted) return;
    indicatorVisible = true;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black38,
        useRootNavigator: true,
        builder: (dialogContext) {
          return PopScope(
            canPop: false,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xff181818),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      loadingLabel,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  });

  try {
    await loadLibrary();
  } finally {
    indicatorTimer.cancel();
    if (indicatorVisible && navigator.context.mounted) {
      navigator.pop();
    }
  }
}
