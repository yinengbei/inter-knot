import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inter_knot/gen/assets.gen.dart';

class Avatar extends StatelessWidget {
  const Avatar(
    this.src, {
    super.key,
    this.size = 40,
    this.onTap,
  });

  final String? src;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasSrc = src != null && src!.trim().isNotEmpty;
    final avatar = ClipOval(
      child: !hasSrc
          ? Assets.images.profilePhoto.image(
              height: size,
              width: size,
              fit: BoxFit.cover,
            )
          : CachedNetworkImage(
              imageUrl: src!.trim(),
              width: size,
              height: size,
              fit: BoxFit.cover,

              progressIndicatorBuilder: (context, url, p) => SizedBox.square(
                dimension: size,
                child: Center(
                  child: CircularProgressIndicator(
                    value: p.totalSize != null
                        ? p.downloaded / p.totalSize!
                        : null,
                  ),
                ),
              ),
              errorWidget: (context, url, error) =>
                  Assets.images.profilePhoto.image(
                height: size,
                width: size,
                fit: BoxFit.cover,
              ),
            ),
    );
    if (onTap == null) return avatar;
    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: avatar,
    );
  }
}
