// dart format width=80

/// GENERATED CODE - DO NOT MODIFY BY HAND
/// *****************************************************
///  FlutterGen
/// *****************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: deprecated_member_use,directives_ordering,implicit_dynamic_list_literal,unnecessary_import

import 'package:flutter/widgets.dart';

class $AssetsFontsGen {
  const $AssetsFontsGen();

  /// File path: assets/fonts/Roboto-Regular.woff2
  String get robotoRegular => 'assets/fonts/Roboto-Regular.woff2';

  /// File path: assets/fonts/zh-cn.ttf
  String get zhCn => 'assets/fonts/zh-cn.ttf';

  /// List of all assets
  List<String> get values => [robotoRegular, zhCn];
}

class $AssetsImagesGen {
  const $AssetsImagesGen();

  /// File path: assets/images/Bangboo.gif
  AssetGenImage get bangboo => const AssetGenImage('assets/images/Bangboo.gif');

  /// File path: assets/images/close-btn.webp
  AssetGenImage get closeBtn =>
      const AssetGenImage('assets/images/close-btn.webp');

  /// File path: assets/images/default-cover.webp
  AssetGenImage get defaultCover =>
      const AssetGenImage('assets/images/default-cover.webp');

  /// File path: assets/images/discussion-page-bg-point.webp
  AssetGenImage get discussionPageBgPoint =>
      const AssetGenImage('assets/images/discussion-page-bg-point.webp');

  /// File path: assets/images/pc-page-bg.png
  AssetGenImage get pcPageBg =>
      const AssetGenImage('assets/images/pc-page-bg.png');

  /// File path: assets/images/profile-photo.webp
  AssetGenImage get profilePhoto =>
      const AssetGenImage('assets/images/profile-photo.webp');

  /// File path: assets/images/tab-bg-point.webp
  AssetGenImage get tabBgPoint =>
      const AssetGenImage('assets/images/tab-bg-point.webp');

  /// File path: assets/images/zzz.webp
  AssetGenImage get zzz => const AssetGenImage('assets/images/zzz.webp');

  /// File path: assets/images/zzzicon.png
  AssetGenImage get zzzicon => const AssetGenImage('assets/images/zzzicon.png');

  /// List of all assets
  List<AssetGenImage> get values => [
        bangboo,
        closeBtn,
        defaultCover,
        discussionPageBgPoint,
        pcPageBg,
        profilePhoto,
        tabBgPoint,
        zzz,
        zzzicon
      ];
}

class Assets {
  const Assets._();

  static const $AssetsFontsGen fonts = $AssetsFontsGen();
  static const $AssetsImagesGen images = $AssetsImagesGen();
}

class AssetGenImage {
  const AssetGenImage(
    this._assetName, {
    this.size,
    this.flavors = const {},
    this.animation,
  });

  final String _assetName;

  final Size? size;
  final Set<String> flavors;
  final AssetGenImageAnimation? animation;

  Image image({
    Key? key,
    AssetBundle? bundle,
    ImageFrameBuilder? frameBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
    String? semanticLabel,
    bool excludeFromSemantics = false,
    double? scale,
    double? width,
    double? height,
    Color? color,
    Animation<double>? opacity,
    BlendMode? colorBlendMode,
    BoxFit? fit,
    AlignmentGeometry alignment = Alignment.center,
    ImageRepeat repeat = ImageRepeat.noRepeat,
    Rect? centerSlice,
    bool matchTextDirection = false,
    bool gaplessPlayback = true,
    bool isAntiAlias = false,
    String? package,
    FilterQuality filterQuality = FilterQuality.medium,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    return Image.asset(
      _assetName,
      key: key,
      bundle: bundle,
      frameBuilder: frameBuilder,
      errorBuilder: errorBuilder,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      scale: scale,
      width: width,
      height: height,
      color: color,
      opacity: opacity,
      colorBlendMode: colorBlendMode,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: matchTextDirection,
      gaplessPlayback: gaplessPlayback,
      isAntiAlias: isAntiAlias,
      package: package,
      filterQuality: filterQuality,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
  }

  ImageProvider provider({
    AssetBundle? bundle,
    String? package,
  }) {
    return AssetImage(
      _assetName,
      bundle: bundle,
      package: package,
    );
  }

  String get path => _assetName;

  String get keyName => _assetName;
}

class AssetGenImageAnimation {
  const AssetGenImageAnimation({
    required this.isAnimation,
    required this.duration,
    required this.frames,
  });

  final bool isAnimation;
  final Duration duration;
  final int frames;
}
