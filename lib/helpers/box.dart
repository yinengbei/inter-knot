import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'legacy_get_storage_migration_stub.dart'
    if (dart.library.io) 'legacy_get_storage_migration_io.dart'
    if (dart.library.html) 'legacy_get_storage_migration_web.dart';

final box = AppBox();

class AppBox {
  static const String _legacyContainerName = 'GetStorage';
  static const String _migrationMarkerKey =
      '__inter_knot_shared_preferences_migrated__';
  static const String _jsonPrefix = '__inter_knot_json__:';

  SharedPreferencesWithCache? _prefs;

  Future<void> init() async {
    if (_prefs != null) return;

    _prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    await _migrateLegacyGetStorageData();
  }

  T? read<T>(String key) {
    final value = _decode(_requirePrefs().get(key));
    if (value == null) return null;
    return value as T?;
  }

  Future<void> write(String key, dynamic value) async {
    final prefs = _requirePrefs();
    if (value == null) {
      await prefs.remove(key);
      return;
    }

    final encoded = _encode(value);
    if (encoded is bool) {
      await prefs.setBool(key, encoded);
      return;
    }
    if (encoded is int) {
      await prefs.setInt(key, encoded);
      return;
    }
    if (encoded is double) {
      await prefs.setDouble(key, encoded);
      return;
    }
    if (encoded is List<String>) {
      await prefs.setStringList(key, encoded);
      return;
    }
    if (encoded is String) {
      await prefs.setString(key, encoded);
      return;
    }

    throw UnsupportedError(
      'Unsupported value type for shared_preferences: ${value.runtimeType}',
    );
  }

  Future<void> remove(String key) {
    return _requirePrefs().remove(key);
  }

  SharedPreferencesWithCache _requirePrefs() {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError('box.init() must complete before storage is used.');
    }
    return prefs;
  }

  Object? _encode(dynamic value) {
    if (value is bool ||
        value is int ||
        value is double ||
        value is String ||
        value is List<String>) {
      return value;
    }
    return '$_jsonPrefix${jsonEncode(value)}';
  }

  Object? _decode(Object? value) {
    if (value is String && value.startsWith(_jsonPrefix)) {
      return jsonDecode(value.substring(_jsonPrefix.length));
    }
    return value;
  }

  Future<void> _migrateLegacyGetStorageData() async {
    final prefs = _requirePrefs();
    if (prefs.getBool(_migrationMarkerKey) == true) return;

    final legacyData = await readLegacyGetStorageData(_legacyContainerName);
    if (legacyData != null && legacyData.isNotEmpty) {
      for (final entry in legacyData.entries) {
        if (prefs.containsKey(entry.key)) continue;
        await write(entry.key, entry.value);
      }
    }

    await prefs.setBool(_migrationMarkerKey, true);
  }
}
