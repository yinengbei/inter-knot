// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

Future<Map<String, dynamic>?> readLegacyGetStorageData(String containerName) {
  final raw = html.window.localStorage[containerName];
  if (raw == null || raw.trim().isEmpty) {
    return Future.value(null);
  }

  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return Future.value(decoded);
    }
    if (decoded is Map) {
      return Future.value(
        decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        ),
      );
    }
  } catch (_) {
    return Future.value(null);
  }

  return Future.value(null);
}
