enum CaptchaScene {
  articleCreate('articleCreate'),
  commentCreate('commentCreate'),
  checkIn('checkIn'),
  login('login'),
  register('register');

  const CaptchaScene(this.key);

  final String key;
}

class CaptchaPayload {
  const CaptchaPayload({
    required this.lotNumber,
    required this.captchaOutput,
    required this.passToken,
    required this.genTime,
  });

  final String lotNumber;
  final String captchaOutput;
  final String passToken;
  final String genTime;

  factory CaptchaPayload.fromJson(Map<String, dynamic> json) {
    final lotNumber = json['lot_number']?.toString() ?? '';
    final captchaOutput = json['captcha_output']?.toString() ?? '';
    final passToken = json['pass_token']?.toString() ?? '';
    final genTime = json['gen_time']?.toString() ?? '';

    if (lotNumber.isEmpty ||
        captchaOutput.isEmpty ||
        passToken.isEmpty ||
        genTime.isEmpty) {
      throw FormatException('验证码结果不完整');
    }

    return CaptchaPayload(
      lotNumber: lotNumber,
      captchaOutput: captchaOutput,
      passToken: passToken,
      genTime: genTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lot_number': lotNumber,
      'captcha_output': captchaOutput,
      'pass_token': passToken,
      'gen_time': genTime,
    };
  }
}

class CaptchaConfigModel {
  const CaptchaConfigModel({
    required this.enabled,
    required this.captchaId,
    required this.scenes,
    required this.sceneModes,
    required this.scenePassTtlSeconds,
  });

  final bool enabled;
  final String captchaId;
  final Map<String, bool> scenes;
  final Map<String, String> sceneModes;
  final Map<String, int> scenePassTtlSeconds;

  factory CaptchaConfigModel.fromJson(Map<String, dynamic> json) {
    final rawScenes = json['scenes'];
    final scenes = <String, bool>{};
    final sceneModes = <String, String>{};
    final scenePassTtlSeconds = <String, int>{};

    if (rawScenes is Map) {
      for (final entry in rawScenes.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is Map) {
          scenes[key] = value['enabled'] != false;
          final mode = value['mode']?.toString();
          if (mode != null && mode.isNotEmpty) {
            sceneModes[key] = mode;
          }
          final ttl = _readTtl(value['passTtlSeconds']);
          if (ttl != null) {
            scenePassTtlSeconds[key] = ttl;
          }
        } else {
          scenes[key] = value == true;
        }
      }
    }

    final rawModes = json['sceneModes'];
    if (rawModes is Map) {
      for (final entry in rawModes.entries) {
        final mode = entry.value?.toString();
        if (mode != null && mode.isNotEmpty) {
          sceneModes[entry.key.toString()] = mode;
        }
      }
    }

    final rawPassTtls = json['passTtlSeconds'];
    if (rawPassTtls is Map) {
      for (final entry in rawPassTtls.entries) {
        final ttl = _readTtl(entry.value);
        if (ttl != null) {
          scenePassTtlSeconds[entry.key.toString()] = ttl;
        }
      }
    }

    return CaptchaConfigModel(
      enabled: json['enabled'] == true,
      captchaId: json['captchaId']?.toString() ?? '',
      scenes: scenes,
      sceneModes: sceneModes,
      scenePassTtlSeconds: scenePassTtlSeconds,
    );
  }

  factory CaptchaConfigModel.disabled() {
    return const CaptchaConfigModel(
      enabled: false,
      captchaId: '',
      scenes: <String, bool>{},
      sceneModes: <String, String>{},
      scenePassTtlSeconds: <String, int>{},
    );
  }

  static int? _readTtl(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  bool isSceneEnabled(CaptchaScene scene) {
    return enabled && captchaId.isNotEmpty && (scenes[scene.key] ?? false);
  }

  bool isRiskUpgradeScene(CaptchaScene scene) {
    return isSceneEnabled(scene) && sceneModes[scene.key] == 'risk-upgrade';
  }

  int? scenePassTtl(CaptchaScene scene) {
    return scenePassTtlSeconds[scene.key];
  }
}
