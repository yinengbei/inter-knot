import 'dart:async';
import 'dart:io';

import 'package:gt4_flutter_plugin/gt4_enum.dart';
import 'package:gt4_flutter_plugin/gt4_flutter_plugin.dart';
import 'package:gt4_flutter_plugin/gt4_session_configuration.dart';
import 'package:inter_knot/api/api_exception.dart';
import 'package:inter_knot/models/captcha.dart';

Future<CaptchaPayload> runCaptchaVerification(String captchaId) async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    throw ApiException('当前平台暂不支持极验验证');
  }

  final completer = Completer<CaptchaPayload>();
  final config = GT4SessionConfiguration();
  config.language = 'zho';
  config.userInterfaceStyle = GTC4UserInterfaceStyle.dark;
  config.debugEnable = false;
  final captcha = Gt4FlutterPlugin(captchaId, config);

  void completeError(Object error, [StackTrace? stackTrace]) {
    if (completer.isCompleted) return;
    try {
      captcha.close();
    } catch (_) {}
    completer.completeError(error, stackTrace);
  }

  void completeSuccess(CaptchaPayload payload) {
    if (completer.isCompleted) return;
    try {
      captcha.close();
    } catch (_) {}
    completer.complete(payload);
  }

  captcha.addEventHandler(
    onResult: (Map<String, dynamic> message) async {
      try {
        final status = message['status']?.toString();
        if (status == '1') {
          final result = message['result'];
          if (result is Map) {
            completeSuccess(
              CaptchaPayload.fromJson(Map<String, dynamic>.from(result)),
            );
            return;
          }
          completeError(ApiException('验证码结果无效'));
          return;
        }
      } catch (e, s) {
        completeError(ApiException('验证码结果解析失败'), s);
      }
    },
    onError: (Map<String, dynamic> message) async {
      final code = message['code']?.toString();
      if (code == '-14460' || code == '-20200') {
        completeError(ApiException('你已取消验证码验证'));
        return;
      }
      completeError(ApiException(message['msg']?.toString() ?? '验证码校验失败'));
    },
  );

  try {
    captcha.verify();
  } catch (e, s) {
    completeError(ApiException('验证码拉起失败'), s);
  }

  return completer.future;
}
