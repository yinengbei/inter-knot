import 'package:flutter/material.dart';

class AsyncWebImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Alignment alignment;
  final FilterQuality filterQuality;
  final int? cacheWidth;
  final int? cacheHeight;
  final bool gaplessPlayback;
  final WebHtmlElementStrategy webHtmlElementStrategy;
  final Widget Function(BuildContext context)? placeholderBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  const AsyncWebImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.low,
    this.cacheWidth,
    this.cacheHeight,
    this.gaplessPlayback = false,
    this.webHtmlElementStrategy = WebHtmlElementStrategy.never,
    this.placeholderBuilder,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      filterQuality: filterQuality,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      gaplessPlayback: gaplessPlayback,
      webHtmlElementStrategy: webHtmlElementStrategy,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: frame != null
              ? child
              : SizedBox(
                  width: width,
                  height: height,
                  child: placeholderBuilder?.call(context) ??
                      Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                ),
        );
      },
      errorBuilder: errorBuilder != null
          ? (context, error, stackTrace) => errorBuilder!(context, error)
          : null,
    );
  }
}
