import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/discussions_grid.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/deferred_routes.dart';
import 'package:inter_knot/helpers/throttle.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with AutomaticKeepAliveClientMixin {
  final c = Get.find<Controller>();

  final keyboardVisibilityController = KeyboardVisibilityController();
  late final keyboardSubscription =
      keyboardVisibilityController.onChange.listen((visible) {
    if (!visible) FocusManager.instance.primaryFocus?.unfocus();
  });

  late final fetchData = retryThrottle(
    c.searchData,
    const Duration(milliseconds: 500),
  );

  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    keyboardSubscription.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 640;

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  isCompact
                      ? RefreshIndicator(
                          edgeOffset: 0,
                          displacement: 56,
                          onRefresh: () async {
                            await c.refreshSearchData();
                          },
                          child: Obx(() {
                            return DiscussionGrid(
                              list: c.searchResult(),
                              hasNextPage: c.searchHasNextPage(),
                              fetchData: fetchData,
                              controller: _scrollController,
                            );
                          }),
                        )
                      : Obx(() {
                          return DiscussionGrid(
                            list: c.searchResult(),
                            hasNextPage: c.searchHasNextPage(),
                            fetchData: fetchData,
                            controller: _scrollController,
                          );
                        }),
                  Positioned(
                    top: 16,
                    left: 0,
                    right: 0,
                    child: Obx(() {
                      final count = c.newPostCount.value;
                      final hasChange = c.hasContentChange.value;
                      final shouldShow = count > 0 || hasChange;

                      String message = '帖子列表有更新';
                      if (count > 0) {
                        message = '有 $count 个新帖子';
                      }

                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        reverseDuration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          final slide = Tween<Offset>(
                            begin: const Offset(0, -0.2),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ));
                          final scale = Tween<double>(
                            begin: 0.96,
                            end: 1.0,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutBack,
                          ));
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: slide,
                              child: ScaleTransition(
                                scale: scale,
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: shouldShow
                            ? Center(
                                key: ValueKey(
                                    'new-post-banner-$count-$hasChange'),
                                child: Material(
                                  color: const Color(0xffD7FF00),
                                  borderRadius: BorderRadius.circular(24),
                                  elevation: 10,
                                  shadowColor: const Color(0xffD7FF00)
                                      .withValues(alpha: 0.45),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(24),
                                    onTap: () async {
                                      await c.showNewPosts();
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                        if (_scrollController.hasClients) {
                                          _scrollController.animateTo(
                                            0,
                                            duration: const Duration(
                                                milliseconds: 500),
                                            curve: Curves.easeOutQuart,
                                          );
                                        }
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.north_rounded,
                                            size: 18,
                                            color: Colors.black,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            message,
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox(
                                key: ValueKey('new-post-banner-hidden'),
                              ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!isCompact)
          Positioned(
            bottom: 24,
            right: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _ZzzDesktopActionButton(
                  icon: Icons.refresh_rounded,
                  label: '刷新',
                  width: 48,
                  iconOnly: true,
                  enableClickFlash: true,
                  onTap: () async {
                    c.refreshSearchData();
                  },
                ),
                const SizedBox(height: 12),
                _ZzzDesktopActionButton(
                  icon: Icons.add,
                  label: '发布委托',
                  width: 188,
                  onTap: () async {
                    if (await c.ensureLogin()) {
                      await showCreateDiscussionPage(context);
                    }
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _ZzzDesktopActionButton extends StatefulWidget {
  const _ZzzDesktopActionButton({
    required this.icon,
    required this.label,
    required this.width,
    required this.onTap,
    this.iconOnly = false,
    this.enableClickFlash = false,
  });

  final IconData icon;
  final String label;
  final double width;
  final Future<void> Function() onTap;
  final bool iconOnly;
  final bool enableClickFlash;

  @override
  State<_ZzzDesktopActionButton> createState() =>
      _ZzzDesktopActionButtonState();
}

class _ZzzDesktopActionButtonState extends State<_ZzzDesktopActionButton>
    with SingleTickerProviderStateMixin {
  static const _hoverColor = Color(0xffD9FA00);
  static const _outerFill = Color(0xff313131);
  static const _specialSauceCurve = Cubic(0.25, 0.1, 0.75, 1);
  static const _buttonHeight = 48.0;
  static const _iconSlotSize = 44.0;

  bool _isHovering = false;
  bool _isFlashing = false;
  bool _isFlashOff = false;
  int _flashToken = 0;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseSpreadAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 670),
    );

    _pulseSpreadAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: -2.0, end: 2.0),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 2.0, end: 7.0),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 7.0, end: 1.0),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: -2.0),
        weight: 25,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: _specialSauceCurve,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _setHovering(bool value) {
    if (_isHovering == value) return;
    setState(() => _isHovering = value);
    _syncPulseState();
  }

  void _syncPulseState() {
    final shouldPulse = _isHovering || _isFlashing;
    if (shouldPulse) {
      if (!_pulseController.isAnimating) {
        _pulseController
          ..reset()
          ..repeat();
      }
      return;
    }

    _pulseController
      ..stop()
      ..reset();
  }

  Future<void> _playClickFlash() async {
    if (!widget.enableClickFlash) return;

    final token = ++_flashToken;
    setState(() {
      _isFlashing = true;
      _isFlashOff = true;
    });
    _syncPulseState();

    Future<void> step(int delayMs, VoidCallback cb) async {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
      if (!mounted || token != _flashToken) return;
      setState(cb);
      _syncPulseState();
    }

    await step(50, () {
      _isFlashOff = false;
    });
    await step(50, () {
      _isFlashOff = true;
    });
    await step(50, () {
      _isFlashOff = false;
    });
    await step(50, () {
      _isFlashing = false;
      _isFlashOff = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.all(Radius.circular(999));

    return MouseRegion(
      onEnter: (_) => _setHovering(true),
      onExit: (_) => _setHovering(false),
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final showPulse = _isHovering || _isFlashing;
          final showActive = showPulse && !_isFlashOff;
          final pulseSpread = showPulse ? _pulseSpreadAnimation.value : 0.0;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              if (showPulse)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: borderRadius,
                        boxShadow: [
                          BoxShadow(
                            color: _hoverColor,
                            blurRadius: 0,
                            spreadRadius: pulseSpread,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  borderRadius: borderRadius,
                  onTap: () async {
                    _playClickFlash();
                    await widget.onTap();
                  },
                  child: AnimatedContainer(
                    duration: Duration.zero,
                    curve: Curves.easeOut,
                    width: widget.width,
                    height: _buttonHeight,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: showActive ? _hoverColor : _outerFill,
                      borderRadius: borderRadius,
                      border: Border.all(
                        color: showActive ? _hoverColor : Colors.black,
                        width: 2,
                      ),
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: borderRadius,
                          child: widget.iconOnly
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ColoredBox(
                                      color: showActive
                                          ? _hoverColor
                                          : Colors.black,
                                    ),
                                    if (!showActive)
                                      const CustomPaint(
                                        painter: _ZzzButtonPatternPainter(),
                                      ),
                                    Center(
                                      child: Icon(
                                        widget.icon,
                                        color: showActive
                                            ? Colors.black
                                            : const Color(0xffefefef),
                                        size: 22,
                                      ),
                                    ),
                                  ],
                                )
                              : Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ColoredBox(
                                      color: showActive
                                          ? _hoverColor
                                          : Colors.black,
                                    ),
                                    if (!showActive)
                                      const CustomPaint(
                                        painter: _ZzzButtonPatternPainter(),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 40,
                                        right: 16,
                                      ),
                                      child: Center(
                                        child: Text(
                                          widget.label,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: showActive
                                                ? Colors.black
                                                : const Color(0xffefefef),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            fontStyle: FontStyle.italic,
                                            height: 1.2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        if (!widget.iconOnly)
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            child: AnimatedContainer(
                              duration: Duration.zero,
                              curve: Curves.easeOut,
                              width: _iconSlotSize,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                borderRadius: borderRadius,
                                border: Border.all(
                                  color: showActive ? _hoverColor : _outerFill,
                                  width: 4,
                                ),
                              ),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      showActive ? Colors.black : _hoverColor,
                                ),
                                child: Icon(
                                  widget.icon,
                                  color:
                                      showActive ? _hoverColor : Colors.black,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ZzzButtonPatternPainter extends CustomPainter {
  const _ZzzButtonPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const blockSize = 4.0;
    final blackPaint = Paint()..color = Colors.black;
    final darkPaint = Paint()..color = const Color(0xff121212);

    for (double y = 0; y < size.height; y += blockSize) {
      for (double x = 0; x < size.width; x += blockSize) {
        final isDark =
            ((x / blockSize).floor() + (y / blockSize).floor()).isOdd;
        canvas.drawRect(
          Rect.fromLTWH(x, y, blockSize, blockSize),
          isDark ? darkPaint : blackPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
