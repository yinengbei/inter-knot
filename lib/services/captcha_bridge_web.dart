import 'dart:async';
import 'dart:js_interop';

import 'package:inter_knot/api/api_exception.dart';
import 'package:inter_knot/models/captcha.dart';

@JS('interKnotVerifyCaptcha')
external JSPromise<_CaptchaResultJS?> _interKnotVerifyCaptcha(JSString captchaId);

extension type _CaptchaResultJS._(JSObject _) implements JSObject {
  external JSString? get lot_number;
  external JSString? get captcha_output;
  external JSString? get pass_token;
  external JSString? get gen_time;
}

Future<CaptchaPayload> runCaptchaVerification(String captchaId) async {
  try {
    final result = await _interKnotVerifyCaptcha(captchaId.toJS).toDart;
    if (result == null) {
      throw ApiException('验证码结果无效');
    }
    return CaptchaPayload.fromJson({
      'lot_number': result.lot_number?.toDart,
      'captcha_output': result.captcha_output?.toDart,
      'pass_token': result.pass_token?.toDart,
      'gen_time': result.gen_time?.toDart,
    });
  } catch (e) {
    if (e is ApiException) rethrow;
    final message = e.toString();
    if (message.contains('CAPTCHA_CANCELLED')) {
      throw ApiException('你已取消验证码验证');
    }
    if (message.contains('验证码')) {
      throw ApiException(message);
    }
    throw ApiException('验证码校验失败');
  }
}
