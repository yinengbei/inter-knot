import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<Map<String, dynamic>?> readLegacyGetStorageData(String containerName) {
  return _readLegacyFile(containerName);
}

Future<Map<String, dynamic>?> _readLegacyFile(String containerName) async {
  final directory = await getApplicationDocumentsDirectory();
  final primaryFile =
      File('${directory.path}${Platform.pathSeparator}$containerName.gs');
  final backupFile =
      File('${directory.path}${Platform.pathSeparator}$containerName.bak');

  final primaryData = await _decodeFile(primaryFile);
  if (primaryData != null) return primaryData;

  return _decodeFile(backupFile);
}

Future<Map<String, dynamic>?> _decodeFile(File file) async {
  if (!await file.exists()) return null;

  try {
    final raw = (await file.readAsString()).trim();
    if (raw.isEmpty) return <String, dynamic>{};

    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
  } catch (_) {
    return null;
  }

  return null;
}
