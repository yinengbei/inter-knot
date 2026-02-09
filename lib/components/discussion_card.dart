import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/avatar.dart';
import 'package:inter_knot/components/comment_count.dart';
import 'package:inter_knot/components/hover_3d.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/gen/assets.gen.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/h_data.dart';
import 'package:url_launcher/url_launcher_string.dart';

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
  double elevation = 1.0;
  late final AnimationController _borderController;
  late final Animation<Color?> _borderAnimation;

  @override
  void initState() {
    super.initState();
    _borderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _borderAnimation = ColorTween(
      begin: Colors.black,
      end: const Color.fromARGB(164, 0, 255, 0), // Pure Neon Green
    ).animate(_borderController);
  }

  @override
  void dispose() {
    _borderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isCompact = MediaQuery.of(context).size.width < 640;

    final child = AnimatedBuilder(
      animation: _borderController,
      builder: (context, child) {
        return Card(
          clipBehavior: Clip.antiAlias,
          elevation: elevation,
          color: const Color(0xff222222),
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
            side: BorderSide(
              width: 4,
              color: _borderAnimation.value ?? Colors.black,
            ),
          ),
          child: child,
        );
      },
      child: Obx(() {
        if (!c.canVisit(widget.discussion, widget.hData.isPin)) {
          return AspectRatio(
            aspectRatio: 5 / 6,
            child: InkWell(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onTap: () => launchUrlString(widget.discussion.url),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '此讨论涉嫌违规',
                    ),
                    Text(
                      '这篇讨论被 ${c.report[widget.discussion.id]!.length} 人举报',
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return InkWell(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          onTap: () {
            _borderController.forward().then((_) {
              if (mounted) _borderController.reverse();
            });
            widget.onTap?.call();
          },
          onTapDown: (_) {
            setState(() => elevation = 4);
            _borderController.forward();
          },
          onTapUp: (_) {
            setState(() => elevation = 1);
          },
          onTapCancel: () {
            setState(() => elevation = 1);
            _borderController.reverse();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 600,
                      minHeight: 100,
                    ),
                    child: Cover(discussion: widget.discussion),
                  ),
                  Positioned(
                    top: 8,
                    left: 12,
                    child: CommentCount(
                      discussion: widget.discussion,
                      color: Colors.white,
                    ),
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
                  style: Theme.of(context).textTheme.titleMedium,
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
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 3,
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        );
      }),
    );

    if (isCompact) return child;
    return Hover3D(child: child);
  }

  @override
  bool get wantKeepAlive => true;
}

class Cover extends StatelessWidget {
  const Cover({super.key, required this.discussion});

  final DiscussionModel discussion;

  @override
  Widget build(BuildContext context) {
    if (discussion.cover == null) {
      return AspectRatio(
        aspectRatio: 643 / 408,
        child: Assets.images.defaultCover.image(
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

    final coverImage = discussion.coverImages.first;
    final double imgW = coverImage.width?.toDouble() ?? 643;
    final double imgH = coverImage.height?.toDouble() ?? 408;
    final double aspectRatio = imgW / imgH;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate the height the image wants to be
        final width = constraints.maxWidth;
        double height = width / aspectRatio;

        // Manually clamp the height to match the parent ConstrainedBox constraints
        // This prevents the placeholder from shrinking horizontally to maintain aspect ratio
        if (height > constraints.maxHeight) height = constraints.maxHeight;
        if (height < constraints.minHeight) height = constraints.minHeight;

        return CachedNetworkImage(
          imageUrl: discussion.cover!,
          width: width,
          height: height,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          placeholder: (context, url) => SizedBox(
            width: width,
            height: height,
          ),
          errorWidget: (context, url, error) => SizedBox(
            width: width,
            height: height,
            child: Assets.images.defaultCover.image(
              fit: BoxFit.cover,
            ),
          ),
        );
      },
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
