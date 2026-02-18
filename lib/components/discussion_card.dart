import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inter_knot/components/avatar.dart';
import 'package:inter_knot/components/hover_3d.dart';
import 'package:inter_knot/gen/assets.gen.dart';
import 'package:inter_knot/models/category.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/h_data.dart';

/// Get color for a category based on its name
Color getCategoryColor(CategoryModel? category) {
  if (category == null) return Colors.grey;

  final name = category.name.toLowerCase();

  // Gaming categories
  if (name.contains('原神') || name.contains('genshin')) {
    return const Color(0xFF7B68EE); // MediumSlateBlue
  } else if (name.contains('绝区零') || name.contains('zzz')) {
    return const Color(0xFFFF6B6B); // Red coral
  } else if (name.contains('崩坏') || name.contains('honkai')) {
    return const Color(0xFFFF69B4); // HotPink
  } else if (name.contains('星穹铁道') || name.contains('starrail')) {
    return const Color(0xFF4169E1); // RoyalBlue
  }

  // Tech categories
  if (name.contains('技术') || name.contains('tech')) {
    return const Color(0xFF20B2AA); // LightSeaGreen
  } else if (name.contains('开发') || name.contains('dev')) {
    return const Color(0xFF32CD32); // LimeGreen
  }

  // General categories
  if (name.contains('讨论') || name.contains('discussion')) {
    return const Color(0xFFFFA500); // Orange
  } else if (name.contains('新闻') || name.contains('news')) {
    return const Color(0xFF1E90FF); // DodgerBlue
  } else if (name.contains('攻略') || name.contains('guide')) {
    return const Color(0xFF9370DB); // MediumPurple
  }

  // Default colors based on name hash for variety
  final hash = name.hashCode;
  final colors = [
    const Color(0xFFE74C3C), // Red
    const Color(0xFF3498DB), // Blue
    const Color(0xFF2ECC71), // Green
    const Color(0xFFF39C12), // Yellow
    const Color(0xFF9B59B6), // Purple
    const Color(0xFF1ABC9C), // Teal
    const Color(0xFFE91E63), // Pink
    const Color(0xFF00BCD4), // Cyan
  ];
  return colors[hash.abs() % colors.length];
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

    final cardContent = MouseRegion(
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
                  color: _isHovering
                      ? (_breathingAnimation.value ?? const Color(0xfffbfe00))
                      : (widget.discussion.isPinned
                          ? Colors.blue
                          : (widget.discussion.category != null
                              ? getCategoryColor(widget.discussion.category)
                              : Colors.black)),
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
                  if (widget.discussion.category != null)
                    Positioned(
                      top: 4,
                      left: widget.discussion.isPinned ? 48 : 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: getCategoryColor(widget.discussion.category),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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

    if (isCompact) return cardContent;
    return Hover3D(child: cardContent);
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
    } else if (discussion.cover!.toLowerCase().contains('.gif')) {
      image = Image.network(
        discussion.cover!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        alignment: Alignment.topCenter,
        filterQuality: FilterQuality.medium,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const ColoredBox(color: Colors.white10);
        },
        errorBuilder: (context, error, stackTrace) =>
            Assets.images.defaultCover.image(
          fit: BoxFit.cover,
        ),
      );
    } else {
      image = CachedNetworkImage(
        imageUrl: discussion.cover!,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        filterQuality: FilterQuality.medium,
        placeholder: (context, url) => const ColoredBox(color: Colors.white10),
        errorWidget: (context, url, error) => Assets.images.defaultCover.image(
          fit: BoxFit.cover,
        ),
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
