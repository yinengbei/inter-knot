import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inter_knot/components/avatar.dart';
import 'package:inter_knot/components/hover_3d.dart';
import 'package:inter_knot/gen/assets.gen.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/h_data.dart';

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
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isCompact = MediaQuery.of(context).size.width < 640;

    final child = Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      color: const Color(0xff222222),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
        side: BorderSide(
          width: 4,
          color: Colors.black,
        ),
      ),
      child: InkWell(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        onTap: widget.onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Cover(discussion: widget.discussion),
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
    final double rawAspectRatio = imgW / imgH;
    // Limit aspect ratio to avoid extremely tall images
    // Using 0.75 (3:4) as the threshold.
    final double displayAspectRatio =
        rawAspectRatio < 0.75 ? 0.75 : rawAspectRatio;

    return AspectRatio(
      aspectRatio: displayAspectRatio,
      child: discussion.cover!.toLowerCase().contains('.gif')
          ? Image.network(
              discussion.cover!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              alignment: Alignment.topCenter,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const ColoredBox(color: Colors.white10);
              },
              errorBuilder: (context, error, stackTrace) =>
                  Assets.images.defaultCover.image(
                fit: BoxFit.cover,
              ),
            )
          : CachedNetworkImage(
              imageUrl: discussion.cover!,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              placeholder: (context, url) =>
                  const ColoredBox(color: Colors.white10),
              errorWidget: (context, url, error) =>
                  Assets.images.defaultCover.image(
                fit: BoxFit.cover,
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
