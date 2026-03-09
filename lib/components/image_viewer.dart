import 'dart:math' as math;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:inter_knot/components/click_region.dart';
import 'package:inter_knot/gen/assets.gen.dart';
import 'package:inter_knot/helpers/dialog_helper.dart';
import 'package:inter_knot/helpers/download_helper.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class ImageViewer extends StatefulWidget {
  const ImageViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.heroTagPrefix,
  });

  final List<String> imageUrls;
  final int initialIndex;
  final String? heroTagPrefix;

  static void show(
    BuildContext context, {
    required List<String> imageUrls,
    int initialIndex = 0,
    String? heroTagPrefix,
  }) {
    showZZZDialog(
      context: context,
      transitionDuration: const Duration(milliseconds: 260),
      showBackgroundEffect: false,
      pageBuilder: (context) => Center(
        child: ImageViewer(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
          heroTagPrefix: heroTagPrefix,
        ),
      ),
    );
  }

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerScrollBehavior extends MaterialScrollBehavior {
  const _ImageViewerScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };
}

class _ImageViewerState extends State<ImageViewer>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  late final List<PhotoViewController> _photoControllers;
  final List<AnimationController> _zoomControllers = [];
  final List<Animation<double>> _zoomAnimations = [];

  Ticker? _wheelTicker;
  Duration? _wheelLast;
  double _wheelVelocity = 0.0;
  final Map<int, Size> _imageSizes = <int, Size>{};
  final List<ImageStream> _imageStreams = <ImageStream>[];
  final List<ImageStreamListener> _imageStreamListeners =
      <ImageStreamListener>[];
  late int _currentIndex;
  bool _showChrome = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _photoControllers = List<PhotoViewController>.generate(
      widget.imageUrls.length,
      (_) => PhotoViewController(),
    );
    _zoomControllers.addAll(
      List<AnimationController>.generate(
        widget.imageUrls.length,
        (_) => AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 160),
        ),
      ),
    );
    _zoomAnimations.addAll(
      List<Animation<double>>.generate(
        widget.imageUrls.length,
        (_) => const AlwaysStoppedAnimation<double>(1),
      ),
    );
    _resolveImageSizes();
    _wheelTicker = createTicker(_onWheelTick);
  }

  @override
  void dispose() {
    for (var i = 0; i < _imageStreams.length; i += 1) {
      _imageStreams[i].removeListener(_imageStreamListeners[i]);
    }
    for (final controller in _zoomControllers) {
      controller.dispose();
    }
    for (final controller in _photoControllers) {
      controller.dispose();
    }
    _pageController.dispose();
    _wheelTicker?.dispose();
    super.dispose();
  }

  void _onWheelTick(Duration elapsed) {
    if (!mounted) return;
    final last = _wheelLast;
    _wheelLast = elapsed;
    if (last == null) return;

    final dtSeconds = (elapsed - last).inMicroseconds / 1e6;
    if (dtSeconds <= 0) return;

    final bounds = _scaleBoundsForCurrent();
    if (bounds == null || _photoControllers.isEmpty) {
      _wheelVelocity = 0;
      _wheelTicker?.stop();
      return;
    }

    final controller = _photoControllers[_currentIndex];
    final currentScale = (controller.scale ?? bounds.minScale)
        .clamp(bounds.minScale, bounds.maxScale);

    if (_wheelVelocity.abs() < 0.02) {
      _wheelVelocity = 0;
      _wheelTicker?.stop();
      return;
    }

    // Integrate zoom velocity into a scale factor.
    // Clamp per-frame so it stays stable on low FPS.
    var factor = math.exp(_wheelVelocity * dtSeconds);
    factor = factor.clamp(0.92, 1.08);

    final nextScale = (currentScale * factor)
        .clamp(bounds.minScale, bounds.maxScale)
        .toDouble();
    controller.scale = nextScale;

    // Exponential decay (friction). Larger k => faster stop.
    const k = 9.0;
    _wheelVelocity *= math.exp(-k * dtSeconds);
  }

  void _resolveImageSizes() {
    for (var i = 0; i < widget.imageUrls.length; i += 1) {
      final provider = _buildImageProvider(widget.imageUrls[i]);
      final stream = provider.resolve(const ImageConfiguration());
      final listener = ImageStreamListener((info, _) {
        final size = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _imageSizes[i] = size;
        });
      });
      stream.addListener(listener);
      _imageStreams.add(stream);
      _imageStreamListeners.add(listener);
    }
  }

  bool _isGifUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final uri = Uri.tryParse(trimmed);
    final path = (uri?.path ?? trimmed).toLowerCase();
    return path.endsWith('.gif');
  }

  ImageProvider _buildImageProvider(String url) {
    if (_isGifUrl(url)) {
      return NetworkImage(url);
    }
    return CachedNetworkImageProvider(url);
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _toggleChrome() {
    setState(() {
      _showChrome = !_showChrome;
    });
  }

  double _calculateContainedScale(Size viewport, Size imageSize) {
    return math.min(
      viewport.width / imageSize.width,
      viewport.height / imageSize.height,
    );
  }

  double _calculateCoveredScale(Size viewport, Size imageSize) {
    return math.max(
      viewport.width / imageSize.width,
      viewport.height / imageSize.height,
    );
  }

  ({double minScale, double maxScale})? _scaleBoundsForCurrent() {
    final imageSize = _imageSizes[_currentIndex];
    if (imageSize == null) {
      return null;
    }
    final viewport = MediaQuery.of(context).size;
    final minScale = _calculateContainedScale(viewport, imageSize);
    final maxScale = _calculateCoveredScale(viewport, imageSize) * 2;
    return (minScale: minScale, maxScale: maxScale);
  }

  void _animateScaleTo(double targetScale) {
    if (_photoControllers.isEmpty) {
      return;
    }
    final controller = _photoControllers[_currentIndex];
    final currentScale = controller.scale ?? targetScale;
    final zoomController = _zoomControllers[_currentIndex];
    zoomController.stop();
    zoomController.reset();
    _zoomAnimations[_currentIndex] = Tween<double>(
      begin: currentScale,
      end: targetScale,
    ).animate(
      CurvedAnimation(parent: zoomController, curve: Curves.easeOutCubic),
    )..addListener(() {
        controller.scale = _zoomAnimations[_currentIndex].value;
      });
    zoomController.forward();
  }

  void _zoomBy(double factor) {
    final bounds = _scaleBoundsForCurrent();
    if (bounds == null) {
      return;
    }
    final controller = _photoControllers[_currentIndex];
    final currentScale = (controller.scale ?? bounds.minScale)
        .clamp(bounds.minScale, bounds.maxScale);
    final nextScale =
        (currentScale * factor).clamp(bounds.minScale, bounds.maxScale);
    _animateScaleTo(nextScale);
  }

  void _resetScale() {
    final bounds = _scaleBoundsForCurrent();
    if (bounds == null) {
      return;
    }
    _photoControllers[_currentIndex].rotation = 0;
    _animateScaleTo(bounds.minScale);
  }

  void _rotateBy(double radians) {
    final controller = _photoControllers[_currentIndex];
    controller.rotation = controller.rotation + radians;
  }

  Widget _buildBlurredBackground() {
    final url = widget.imageUrls[_currentIndex];
    return Stack(
      fit: StackFit.expand,
      children: [
        Image(
          image: _buildImageProvider(url),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.low,
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
          child: Container(
            color: Colors.black.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: label,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xff222222),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xff2D2D2D), width: 4),
        ),
        child: ClickRegion(
          onTap: onPressed,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  void _handlePointerScroll(PointerScrollEvent event) {
    final bounds = _scaleBoundsForCurrent();
    if (bounds == null || _photoControllers.isEmpty) {
      return;
    }

    final dy = event.scrollDelta.dy;
    if (dy.abs() < 0.01) return;

    // Add impulse to a zoom velocity, then let the ticker apply damping.
    // Negative dy usually means scrolling up => zoom in.
    final impulse = (-dy * 0.018).clamp(-1.2, 1.2);
    _wheelVelocity = (_wheelVelocity + impulse).clamp(-3.0, 3.0);

    if (_wheelTicker != null && !_wheelTicker!.isActive) {
      _wheelLast = null;
      _wheelTicker!.start();
    }
  }

  void _goToPage(int index, int total) {
    if (total <= 1) return;
    final target = index.clamp(0, total - 1);
    if (target == _currentIndex) return;
    _pageController.jumpToPage(target);
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xff222222),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xff2D2D2D), width: 4),
      ),
      child: ClickRegion(
        onTap: onTap,
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double chromeOpacity = _showChrome ? 1.0 : 0.0;
    final total = widget.imageUrls.length;

    void closeViewer() {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Shortcuts(
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.escape): const DismissIntent(),
        },
        child: Actions(
          actions: {
            DismissIntent: CallbackAction<DismissIntent>(
              onInvoke: (_) {
                closeViewer();
                return null;
              },
            ),
          },
          child: Focus(
            autofocus: true,
            child: Stack(
              children: [
                Container(
                  margin: EdgeInsets.only(
                    left: 8,
                    right: 8,
                    top: MediaQuery.of(context).padding.top + 8,
                    bottom: 8,
                  ),
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color.fromARGB(59, 255, 255, 255),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: Assets.images.discussionPageBgPoint
                                    .provider(),
                                repeat: ImageRepeat.repeat,
                              ),
                              gradient: const LinearGradient(
                                colors: [Color(0xff161616), Color(0xff080808)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomLeft,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${_currentIndex + 1} / $total',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                ClickRegion(
                                  child: Assets.images.closeBtn.image(),
                                  onTap: closeViewer,
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Stack(
                              children: [
                                // ── Blurred background (current image, cover-fit + blur) ──
                                Positioned.fill(
                                  child: ClipRect(
                                    child: _buildBlurredBackground(),
                                  ),
                                ),
                                Positioned.fill(
                                  child: Listener(
                                    onPointerSignal: (event) {
                                      if (event is PointerScrollEvent) {
                                        _handlePointerScroll(event);
                                      }
                                    },
                                    child: GestureDetector(
                                      onTap: _toggleChrome,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          top: 12,
                                          bottom: 68,
                                        ),
                                        child: ScrollConfiguration(
                                          behavior:
                                              const _ImageViewerScrollBehavior(),
                                          child: PhotoViewGallery.builder(
                                            scrollPhysics:
                                                const PageScrollPhysics(),
                                            builder: (BuildContext context,
                                                int index) {
                                              final url =
                                                  widget.imageUrls[index];
                                              final heroTag = widget
                                                          .heroTagPrefix !=
                                                      null
                                                  ? '${widget.heroTagPrefix}-$index'
                                                  : url;

                                              return PhotoViewGalleryPageOptions(
                                                imageProvider:
                                                    _buildImageProvider(url),
                                                initialScale:
                                                    PhotoViewComputedScale
                                                        .contained,
                                                minScale: PhotoViewComputedScale
                                                    .contained,
                                                maxScale: PhotoViewComputedScale
                                                        .covered *
                                                    2,
                                                filterQuality:
                                                    FilterQuality.medium,
                                                heroAttributes:
                                                    PhotoViewHeroAttributes(
                                                        tag: heroTag),
                                                controller:
                                                    _photoControllers[index],
                                                errorBuilder: (context, error,
                                                    stackTrace) {
                                                  return const Center(
                                                    child: Icon(
                                                      Icons.broken_image,
                                                      color: Colors.white,
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                            itemCount: widget.imageUrls.length,
                                            loadingBuilder: (context, event) =>
                                                Center(
                                              child: SizedBox(
                                                width: 20.0,
                                                height: 20.0,
                                                child:
                                                    CircularProgressIndicator(
                                                  value: event == null
                                                      ? 0
                                                      : event.cumulativeBytesLoaded /
                                                          (event.expectedTotalBytes ??
                                                              1),
                                                ),
                                              ),
                                            ),
                                            backgroundDecoration:
                                                const BoxDecoration(
                                                    color: Colors.transparent),
                                            pageController: _pageController,
                                            onPageChanged: _onPageChanged,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (total > 1)
                                  Positioned(
                                    left: 12,
                                    top: 0,
                                    bottom: 0,
                                    child: IgnorePointer(
                                      ignoring: chromeOpacity == 0.0,
                                      child: AnimatedOpacity(
                                        duration:
                                            const Duration(milliseconds: 180),
                                        opacity: chromeOpacity,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: _buildNavButton(
                                            icon: Icons.chevron_left,
                                            onTap: () => _goToPage(
                                                _currentIndex - 1, total),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (total > 1)
                                  Positioned(
                                    right: 12,
                                    top: 0,
                                    bottom: 0,
                                    child: IgnorePointer(
                                      ignoring: chromeOpacity == 0.0,
                                      child: AnimatedOpacity(
                                        duration:
                                            const Duration(milliseconds: 180),
                                        opacity: chromeOpacity,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: _buildNavButton(
                                            icon: Icons.chevron_right,
                                            onTap: () => _goToPage(
                                                _currentIndex + 1, total),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: IgnorePointer(
                                    ignoring: chromeOpacity == 0.0,
                                    child: AnimatedOpacity(
                                      duration:
                                          const Duration(milliseconds: 180),
                                      opacity: chromeOpacity,
                                      child: Container(
                                        height: 56,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6),
                                        decoration: const BoxDecoration(
                                          color: Color(0xff121212),
                                          border: Border(
                                            top: BorderSide(
                                              color: Color(0xff313132),
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            _buildToolButton(
                                              icon: Icons.file_download,
                                              label: '下载',
                                              onPressed: () {
                                                DownloadHelper.downloadImage(
                                                    widget.imageUrls[
                                                        _currentIndex]);
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                            _buildToolButton(
                                              icon: Icons.zoom_out,
                                              label: '缩小',
                                              onPressed: () => _zoomBy(0.9),
                                            ),
                                            const SizedBox(width: 8),
                                            _buildToolButton(
                                              icon: Icons.zoom_in,
                                              label: '放大',
                                              onPressed: () => _zoomBy(1.1),
                                            ),
                                            const SizedBox(width: 8),
                                            _buildToolButton(
                                              icon: Icons.refresh,
                                              label: '复位',
                                              onPressed: _resetScale,
                                            ),
                                            const SizedBox(width: 8),
                                            _buildToolButton(
                                              icon: Icons.rotate_right,
                                              label: '反转',
                                              onPressed: () =>
                                                  _rotateBy(math.pi / 2),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
