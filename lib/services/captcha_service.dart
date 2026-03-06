import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/api/api_exception.dart';
import 'package:inter_knot/models/captcha.dart';
import 'package:inter_knot/services/captcha_bridge.dart';

class CaptchaService extends GetxService {
  final config = CaptchaConfigModel.disabled().obs;

  bool _hasLoadedConfig = false;
  bool _lastLoadFailed = false;

  Api get _api => Get.find<Api>();

  Future<CaptchaService> init() async {
    try {
      await refreshConfig();
    } catch (_) {}
    return this;
  }

  Future<CaptchaConfigModel> refreshConfig() async {
    try {
      final nextConfig = await _api.getCaptchaConfig();
      config.value = nextConfig;
      _hasLoadedConfig = true;
      _lastLoadFailed = false;
      return nextConfig;
    } catch (_) {
      _lastLoadFailed = true;
      rethrow;
    }
  }

  Future<CaptchaConfigModel> ensureConfigLoaded() async {
    if (!_hasLoadedConfig || _lastLoadFailed) {
      return refreshConfig();
    }
    return config.value;
  }

  Future<CaptchaPayload?> verifyIfNeeded(CaptchaScene scene) async {
    final currentConfig = await ensureConfigLoaded();
    if (!currentConfig.isSceneEnabled(scene)) {
      return null;
    }
    if (currentConfig.captchaId.isEmpty) {
      throw ApiException('验证码配置缺失');
    }
    return runCaptchaVerification(currentConfig.captchaId);
  }

  Future<CaptchaPayload> verifyForRequiredResponse({
    required CaptchaScene fallbackScene,
    dynamic body,
  }) async {
    final currentConfig = await ensureConfigLoaded();
    if (!currentConfig.enabled || currentConfig.captchaId.isEmpty) {
      throw ApiException('验证码配置缺失');
    }

    final details = extractErrorDetails(body);
    final scene = parseScene(details?['scene']) ?? fallbackScene;
    if (!currentConfig.isSceneEnabled(scene) && !currentConfig.enabled) {
      throw ApiException('验证码配置缺失');
    }

    return runCaptchaVerification(currentConfig.captchaId);
  }

  static String? extractErrorCode(dynamic body) {
    if (body is! Map) return null;
    final error = body['error'];
    if (error is! Map) return null;
    return error['code']?.toString();
  }

  static Map<String, dynamic>? extractErrorDetails(dynamic body) {
    if (body is! Map) return null;
    final error = body['error'];
    if (error is! Map) return null;
    final details = error['details'];
    if (details is! Map) return null;
    return Map<String, dynamic>.from(details);
  }

  static CaptchaScene? parseScene(dynamic rawScene) {
    final sceneKey = rawScene?.toString();
    if (sceneKey == null || sceneKey.isEmpty) return null;
    for (final scene in CaptchaScene.values) {
      if (scene.key == sceneKey) {
        return scene;
      }
    }
    return null;
  }

  static bool isCaptchaRequiredResponse(
    dynamic body, {
    CaptchaScene? expectedScene,
  }) {
    if (extractErrorCode(body) != 'CAPTCHA_REQUIRED') {
      return false;
    }

    if (expectedScene == null) {
      return true;
    }

    final actualScene = parseScene(extractErrorDetails(body)?['scene']);
    return actualScene == null || actualScene == expectedScene;
  }

  static String? resolveErrorMessageFromBody(dynamic body) {
    if (body is! Map) return null;
    final error = body['error'];
    if (error is! Map) return null;
    return resolveErrorMessageFromCode(error['code']?.toString()) ??
        error['message']?.toString();
  }

  static String? resolveErrorMessageFromCode(String? code) {
    switch (code) {
      case 'CAPTCHA_REQUIRED':
        return '请先完成验证码验证';
      case 'CAPTCHA_INVALID':
        return '验证码未通过，请重试';
      case 'CAPTCHA_VERIFY_FAILED':
        return '验证码服务异常，请稍后重试';
      case 'CAPTCHA_NOT_CONFIGURED':
        return '验证码服务未配置完成，请稍后再试';
      default:
        return null;
    }
  }

  static String? resolveErrorMessageFromException(Object error) {
    if (error is! ApiException) return null;
    final details = error.details;
    if (details is Map) {
      return resolveErrorMessageFromBody(details) ?? error.message;
    }
    return resolveErrorMessageFromCode(error.message) ?? error.message;
  }
}
