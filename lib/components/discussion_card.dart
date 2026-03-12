import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/async_web_image.dart';
import 'package:inter_knot/components/avatar.dart';
import 'package:inter_knot/components/hover_3d.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/gen/assets.gen.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/h_data.dart';

const _discussionCardOuterRadius = BorderRadius.only(
  topLeft: Radius.circular(24),
  topRight: Radius.circular(24),
  bottomLeft: Radius.circular(24),
);
const _discussionCardInnerRadius = BorderRadius.only(
  topLeft: Radius.circular(20),
  topRight: Radius.circular(20),
  bottomLeft: Radius.circular(20),
);
const _discussionCardBorderWidth = 4.0;
const _discussionCardFill = Color(0xff222222);

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
    this.fadeInDuration,
    this.fadeOutDuration,
    this.preferHtmlElementOnWeb = false,
  });

  final String? url;
  final BoxFit fit;
  final Alignment alignment;
  final FilterQuality filterQuality;
  final bool gaplessPlayback;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final Duration? fadeInDuration;
  final Duration? fadeOutDuration;
  final bool preferHtmlElementOnWeb;
  final Widget Function(BuildContext context, double? progress) loadingBuilder;
  final Widget Function(BuildContext context) errorBuilder;

  @override
  Widget build(BuildContext context) {
    final src = url?.trim();
    if (src == null || src.isEmpty) {
      return errorBuilder(context);
    }

    if (kIsWeb) {
      return AsyncWebImage(
        url: src,
        fit: fit,
        alignment: alignment,
        filterQuality: filterQuality,
        cacheWidth: memCacheWidth,
        cacheHeight: memCacheHeight,
        gaplessPlayback: gaplessPlayback,
        webHtmlElementStrategy: preferHtmlElementOnWeb
            ? WebHtmlElementStrategy.prefer
            : WebHtmlElementStrategy.never,
        placeholderBuilder: (context) => loadingBuilder(context, null),
        errorBuilder: (context, error) => errorBuilder(context),
      );
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
      placeholder: (context, url) => loadingBuilder(context, null),
      fadeInDuration: fadeInDuration ?? const Duration(milliseconds: 500),
      fadeOutDuration: fadeOutDuration ?? const Duration(milliseconds: 1000),
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
      child: AnimatedBuilder(
        animation: _breathingAnimation,
        builder: (context, child) {
          final borderColor = _isHovering
              ? (_breathingAnimation.value ?? const Color(0xfffbfe00))
              : (widget.discussion.isPinned ? Colors.blue : Colors.black);
          return Card(
            clipBehavior: Clip.antiAlias,
            elevation: 1,
            color: borderColor,
            shape: const RoundedRectangleBorder(
              borderRadius: _discussionCardOuterRadius,
            ),
            child: Padding(
              padding: const EdgeInsets.all(_discussionCardBorderWidth),
              child: ClipRRect(
                borderRadius: _discussionCardInnerRadius,
                child: Material(
                  color: _discussionCardFill,
                  child: InkWell(
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    onTap: widget.onTap,
                    child: child,
                  ),
                ),
              ),
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
                Positioned(
                  top: 11,
                  left: 16,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.remove_red_eye_outlined,
                          size: 24, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.discussion.views}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              offset: Offset(1, 1),
                              blurRadius: 2,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.hData.isEditableDraft)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _DraftBadge(
                      label: widget.hData.hasPublishedVersion ? '待发布更新' : '草稿',
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
                      top: -28,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: _discussionCardFill,
                          shape: BoxShape.circle,
                        ),
                        child: Avatar(
                          widget.discussion.author.avatar,
                          size: 50,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 54),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Obx(() {
                            final user = Get.find<Controller>().user.value;
                            final authorId =
                                Get.find<Controller>().authorId.value ??
                                    user?.authorId;
                            final isMe = authorId != null &&
                                authorId == widget.discussion.author.authorId;

                            return Text(
                              widget.discussion.author.name,
                              style: TextStyle(
                                color: isMe
                                    ? const Color(0xFFFFBC2E)
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            );
                          }),
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
                      color:
                          widget.discussion.isRead ? Colors.grey : Colors.blue,
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
    );

    if (isCompact) return child;
    return Hover3D(child: child);
  }

  @override
  bool get wantKeepAlive => true;
}

class _DraftBadge extends StatelessWidget {
  const _DraftBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xffD7FF00).withValues(alpha: 0.42),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xffD7FF00),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class Cover extends StatefulWidget {
  const Cover({
    super.key,
    required this.discussion,
    this.isHovering = false,
  });

  final DiscussionModel discussion;
  final bool isHovering;

  @override
  State<Cover> createState() => _CoverState();
}

class _CoverState extends State<Cover> {
  String? _resolvedImageUrl;
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;

  void _resolveImageAspectRatio(String imageUrl) {
    if (_resolvedImageUrl == imageUrl) {
      return;
    }

    if (_imageStream != null && _imageStreamListener != null) {
      _imageStream!.removeListener(_imageStreamListener!);
    }

    _resolvedImageUrl = imageUrl;
    final imageStream = NetworkImage(imageUrl).resolve(
      const ImageConfiguration(),
    );
    final imageStreamListener = ImageStreamListener((info, _) {
      if (!mounted || _resolvedImageUrl != imageUrl) {
        return;
      }

      setState(() {
        final image = info.image;
        _imageAspectRatio = image.width / image.height;
      });
    });

    _imageStream = imageStream;
    _imageStreamListener = imageStreamListener;
    imageStream.addListener(imageStreamListener);
  }

  @override
  void dispose() {
    if (_imageStream != null && _imageStreamListener != null) {
      _imageStream!.removeListener(_imageStreamListener!);
    }
    super.dispose();
  }

  double? _imageAspectRatio; // 图片加载后的实际宽高比

  @override
  Widget build(BuildContext context) {
    // Prefer the high-res image from coverImages if available
    final highResUrl = widget.discussion.coverImages.isNotEmpty
        ? widget.discussion.coverImages.first.url
        : widget.discussion.cover;

    Widget image;
    if (highResUrl == null) {
      image = Assets.images.defaultCover.image(
        width: double.infinity,
        fit: BoxFit.cover,
      );
    } else {
      _resolveImageAspectRatio(highResUrl);
      image = NetworkImageBox(
        url: highResUrl,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
        preferHtmlElementOnWeb: true,
        loadingBuilder: (context, progress) {
          return const SizedBox.shrink();
        },
        errorBuilder: (context) =>
            Assets.images.defaultCover.image(fit: BoxFit.cover),
        /* frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (frame != null && _imageAspectRatio == null) {
            // 图片加载完成，获取实际尺寸
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final imageStream = NetworkImage(highResUrl).resolve(
                const ImageConfiguration(),
              );
              imageStream.addListener(
                ImageStreamListener((info, _) {
                  if (mounted) {
                    setState(() {
                      final image = info.image;
                      _imageAspectRatio = image.width / image.height;
                    });
                  }
                }),
              );
            });
          }
          return child;
        }, */
      );
    }

    // 使用图片加载后的实际宽高比，如果还没加载完则使用默认值 643:408
    final double displayAspectRatio = _imageAspectRatio ?? (643 / 408);

    // 限制最小宽高比，防止图片过高
    // 最小宽高比 0.75 (3:4)，即高度最多是宽度的 1.33 倍
    final double clampedAspectRatio =
        displayAspectRatio < 0.75 ? 0.75 : displayAspectRatio;

    return AspectRatio(
      aspectRatio: clampedAspectRatio,
      child: ClipRect(
        child: AnimatedScale(
          scale: widget.isHovering ? 1.1 : 1.0,
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
      color: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: _discussionCardOuterRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.all(_discussionCardBorderWidth),
        child: ClipRRect(
          borderRadius: _discussionCardInnerRadius,
          child: ColoredBox(
            color: _discussionCardFill,
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
                          top: -28,
                          child: Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _discussionCardFill,
                                width: 2,
                              ),
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
          ),
        ),
      ),
    );
  }
}
