import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

enum UploadImageFormat {
  webp,
  jpg,
}

class CompressedImageData {
  const CompressedImageData({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String filename;
  final String mimeType;
}

/// 上传前自动压缩图片，减少传输体积，提升上传速度。
/// 支持 Web / Android / iOS / macOS。
class ImageCompressHelper {
  ImageCompressHelper._();

  /// 最大边长（像素），超过此值会等比缩放
  static const int _maxDimension = 1920;

  /// JPEG 压缩质量 (0-100)
  static const int _quality = 82;

  /// 压缩图片字节数据
  ///
  /// [bytes] 原始图片二进制
  /// [filename] 文件名，用于判断格式
  /// [mimeType] MIME 类型
  ///
  /// 返回压缩后的字节数据/文件名/MIME。
  /// - 目标 WebP：先尝试高质量 WebP，再尝试有损 WebP，均不优于原图则回退原图。
  /// - 目标 JPG：转 JPEG，有损后不优于原图则回退原图。
  static Future<CompressedImageData> compress({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    required UploadImageFormat targetFormat,
  }) async {
    // GIF 不压缩（会丢失动画）
    if (_isGif(filename, mimeType)) {
      return _origin(bytes: bytes, filename: filename, mimeType: mimeType);
    }

    if (targetFormat == UploadImageFormat.jpg) {
      return _compressAsJpg(bytes: bytes, filename: filename, mimeType: mimeType);
    }
    return _compressAsWebp(bytes: bytes, filename: filename, mimeType: mimeType);
  }

  static Future<CompressedImageData> _compressAsWebp({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    final losslessLike = await _tryCompress(
      bytes: bytes,
      format: CompressFormat.webp,
      quality: 100,
    );
    if (losslessLike != null && losslessLike.length < bytes.length) {
      debugPrint(
        '[ImageCompress] WEBP(100) ${bytes.length} -> ${losslessLike.length} bytes',
      );
      return CompressedImageData(
        bytes: Uint8List.fromList(losslessLike),
        filename: _replaceExtension(filename, 'webp'),
        mimeType: 'image/webp',
      );
    }

    final lossy = await _tryCompress(
      bytes: bytes,
      format: CompressFormat.webp,
      quality: _quality,
    );
    if (lossy != null && lossy.length < bytes.length) {
      debugPrint(
        '[ImageCompress] WEBP($_quality) ${bytes.length} -> ${lossy.length} bytes',
      );
      return CompressedImageData(
        bytes: Uint8List.fromList(lossy),
        filename: _replaceExtension(filename, 'webp'),
        mimeType: 'image/webp',
      );
    }

    debugPrint('[ImageCompress] WEBP fallback to original for $filename');
    return _origin(bytes: bytes, filename: filename, mimeType: mimeType);
  }

  static Future<CompressedImageData> _compressAsJpg({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    final result = await _tryCompress(
      bytes: bytes,
      format: CompressFormat.jpeg,
      quality: _quality,
    );
    if (result != null && result.length < bytes.length) {
      debugPrint(
        '[ImageCompress] JPG($_quality) ${bytes.length} -> ${result.length} bytes',
      );
      return CompressedImageData(
        bytes: Uint8List.fromList(result),
        filename: _replaceExtension(filename, 'jpg'),
        mimeType: 'image/jpeg',
      );
    }

    debugPrint('[ImageCompress] JPG fallback to original for $filename');
    return _origin(bytes: bytes, filename: filename, mimeType: mimeType);
  }

  static Future<Uint8List?> _tryCompress({
    required Uint8List bytes,
    required CompressFormat format,
    required int quality,
  }) async {
    try {
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: _maxDimension,
        minHeight: _maxDimension,
        quality: quality,
        format: format,
      );
      return result;
    } catch (e) {
      debugPrint('[ImageCompress] Failed: $e');
      return null;
    }
  }

  static CompressedImageData _origin({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) {
    return CompressedImageData(
      bytes: bytes,
      filename: filename,
      mimeType: _normalizeMimeType(filename: filename, mimeType: mimeType),
    );
  }

  static String _replaceExtension(String filename, String newExt) {
    final dot = filename.lastIndexOf('.');
    final lowerExt = newExt.toLowerCase();
    if (dot <= 0 || dot == filename.length - 1) {
      return '$filename.$lowerExt';
    }
    return '${filename.substring(0, dot)}.$lowerExt';
  }

  static String _normalizeMimeType({
    required String filename,
    required String mimeType,
  }) {
    final lower = mimeType.toLowerCase();
    if (lower.startsWith('image/')) return lower;
    if (_isPng(filename, lower)) return 'image/png';
    if (_isWebp(filename, lower)) return 'image/webp';
    if (_isGif(filename, lower)) return 'image/gif';
    return 'image/jpeg';
  }

  static bool _isGif(String filename, String mimeType) =>
      mimeType.contains('gif') ||
      filename.toLowerCase().endsWith('.gif');

  static bool _isPng(String filename, String mimeType) =>
      mimeType.contains('png') ||
      filename.toLowerCase().endsWith('.png');

  static bool _isWebp(String filename, String mimeType) =>
      mimeType.contains('webp') ||
      filename.toLowerCase().endsWith('.webp');
}
