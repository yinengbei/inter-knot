import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inter_knot/components/avatar.dart';
import 'package:inter_knot/components/hover_3d.dart';
import 'package:inter_knot/gen/assets.gen.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/category.dart';
import 'package:inter_knot/models/h_data.dart';

class NetworkImageBox extends StatelessWidget {
  const NetworkImageBox({
    super.key,
    required this.url,
    required this.fit,
    required this.loadingBuilder,
    required this.errorBuilder,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.low,
    this.gaplessPlayback = false,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  final String? url;
  final BoxFit fit;
  final Alignment alignment;
  final FilterQuality filterQuality;
  final bool gaplessPlayback;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final Widget Function(BuildContext context, double? progress) loadingBuilder;
  final Widget Function(BuildContext context) errorBuilder;

  @override
  Widget build(BuildContext context) {
    final src = url?.trim();
    if (src == null || src.isEmpty) {
      return errorBuilder(context);
    }
    final isGif = src.toLowerCase().contains('.gif');
    if (isGif) {
      return Image.network(
        src,
        fit: fit,
        alignment: alignment,
        filterQuality: filterQuality,
        gaplessPlayback: gaplessPlayback,
        cacheWidth: memCacheWidth,
        cacheHeight: memCacheHeight,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          final value = progress.expectedTotalBytes != null
              ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
              : null;
          return loadingBuilder(context, value);
        },
        errorBuilder: (context, error, stackTrace) => errorBuilder(context),
      );
    }
    return CachedNetworkImage(
      imageUrl: src,
      fit: fit,
      alignment: alignment,
      filterQuality: filterQuality,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      progressIndicatorBuilder: (context, url, progress) {
        final value = progress.totalSize == null
            ? null
            : progress.downloaded / progress.totalSize!;
        return loadingBuilder(context, value);
      },
      errorWidget: (context, url, error) => errorBuilder(context),
    );
  }
}

class DiscussionCard extends StatefulWidget {
  const DiscussionCard({
    super.key,
    this.onTap,
    required this.discussion,
    required this.hData,
  });

  final DiscussionModel discussion;
  final HDataModel hData;
  final void Function()? onTap;

  @override
  State<DiscussionCard> createState() => _DiscussionCardState();
}

class _DiscussionCardState extends State<DiscussionCard>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  bool _isHovering = false;
  late final AnimationController _breathingController;
  late final Animation<Color?> _breathingAnimation;

  @override
  void initState() {
    super.initState();
    // Controller for the breathing effect (yellow <-> lemon)
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _breathingAnimation = ColorTween(
      begin: const Color(0xfffbfe00),
      end: const Color(0xffdcfe00),
    ).animate(CurvedAnimation(
      parent: _breathingController,
      curve: Curves.linear,
    ));
  }

  @override
  void dispose() {
    _breathingController.dispose();
    super.dispose();
  }

  /// 获取卡片边框颜色
  Color _getBorderColor() {
    // 悬停时优先显示黄色呼吸动画
    if (_isHovering) {
      return _breathingAnimation.value ?? const Color(0xfffbfe00);
    }
    // 置顶时显示蓝色
    if (widget.discussion.isPinned) {
      return Colors.blue;
    }
    // 有类别时显示类别颜色
    if (widget.discussion.category != null) {
      return widget.discussion.category!.color;
    }
    // 默认黑色
    return Colors.black;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isCompact = MediaQuery.of(context).size.width < 640;

    final child = MouseRegion(
      onEnter: (_) {
        setState(() => _isHovering = true);
        _breathingController.reset();
        _breathingController.repeat(reverse: true);
      },
      onExit: (_) {
        setState(() => _isHovering = false);
        _breathingController.stop();
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 1,
        color: const Color(0xff222222),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          ),
        ),
        child: AnimatedBuilder(
          animation: _breathingAnimation,
          builder: (context, child) {
            return Container(
              foregroundDecoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                border: Border.all(
                  width: 4,
                  color: _getBorderColor(),
                ),
              ),
              child: InkWell(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                hoverColor: Colors.transparent,
                onTap: widget.onTap,
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Cover(
                    discussion: widget.discussion,
                    isHovering: _isHovering,
                  ),
                  if (widget.hData.isPin)
                    const Positioned(
                      top: 8,
                      right: 12,
                      child: Text(
                        '置顶',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  if (widget.discussion.isPinned)
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.only(
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        child: const Text(
                          '置顶',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // 类别标签
                  if (widget.discussion.category != null)
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.discussion.category!.color,
                          borderRadius: const BorderRadius.only(
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        child: Text(
                          widget.discussion.category!.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.centerLeft,
                    children: [
                      Positioned(
                        top: -26,
                        child: Avatar(
                          widget.discussion.author.avatar,
                          size: 50,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 54),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              widget.discussion.author.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            const Divider(height: 1),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  widget.discussion.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: widget.discussion.isRead
                            ? Colors.grey
                            : Colors.blue,
                      ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              if (widget.discussion.rawBodyText.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    widget.discussion.bodyText,
                    style: const TextStyle(
                      color: Color(0xffE0E0E0),
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );

    if (isCompact) return child;
    return Hover3D(child: child);
  }

  @override
  bool get wantKeepAlive => true;
}

class Cover extends StatelessWidget {
  const Cover({
    super.key,
    required this.discussion,
    required this.isHovering,
  });

  final DiscussionModel discussion;
  final bool isHovering;

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (discussion.cover == null) {
      image = Assets.images.defaultCover.image(
        width: double.infinity,
        fit: BoxFit.cover,
      );
    } else {
      image = NetworkImageBox(
        url: discussion.cover!,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        memCacheWidth: 400, // Optimize memory usage for grid items
        loadingBuilder: (context, progress) =>
            const ColoredBox(color: Colors.white10),
        errorBuilder: (context) =>
            Assets.images.defaultCover.image(fit: BoxFit.cover),
      );
    }

    // Calculate aspect ratio logic...
    final coverImage =
        discussion.coverImages.isNotEmpty ? discussion.coverImages.first : null;
    final double imgW = coverImage?.width?.toDouble() ?? 643;
    final double imgH = coverImage?.height?.toDouble() ?? 408;
    final double rawAspectRatio = imgW / imgH;
    final double displayAspectRatio =
        rawAspectRatio < 0.75 ? 0.75 : rawAspectRatio;

    return AspectRatio(
      aspectRatio: displayAspectRatio,
      child: ClipRect(
        child: AnimatedScale(
          scale: isHovering ? 1.1 : 1.0,
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeOutCubic,
          child: image,
        ),
      ),
    );
  }
}

class DiscussionCardSkeleton extends StatelessWidget {
  const DiscussionCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      color: const Color(0xff222222),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
        side: BorderSide(width: 4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover placeholder
          const AspectRatio(
            aspectRatio: 643 / 408,
            child: ColoredBox(color: Colors.white10),
          ),
          SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  // Avatar placeholder
                  Positioned(
                    top: -26,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        color: Colors.white10,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 54),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        // Author name placeholder
                        Container(
                          width: 80,
                          height: 14,
                          color: Colors.white10,
                        ),
                        const SizedBox(height: 4),
                        const Divider(height: 1),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Title placeholder
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              width: double.infinity,
              height: 16,
              color: Colors.white10,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              width: 200,
              height: 16,
              color: Colors.white10,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
