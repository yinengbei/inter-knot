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
          : Image.network(
              src!.trim(),
              width: size,
              height: size,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, p) {
                if (p == null) return child;
                return SizedBox.square(
                  dimension: size,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: p.expectedTotalBytes == null
                          ? null
                          : p.cumulativeBytesLoaded / p.expectedTotalBytes!,
                    ),
                  ),
                );
              },
              errorBuilder: (context, e, s) => Assets.images.profilePhoto.image(
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
