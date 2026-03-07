import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

/// Download status
enum DownloadStatus {
  idle,
  downloading,
  completed,
  failed,
}

/// App update service for checking and downloading updates
class UpdateService {
  static const String versionCheckUrl = 'http://ik.tiwat.cn/app/android/version.json';
  
  // Global download state
  static DownloadStatus _downloadStatus = DownloadStatus.idle;
  static double _downloadProgress = 0.0;
  static int _receivedBytes = 0;
  static int _totalBytes = 0;
  static String? _downloadedFilePath;
  static String _statusMessage = '';
  
  // Latest version info for UI notification
  static UpdateInfo? _latestUpdateInfo;
  
  static DownloadStatus get downloadStatus => _downloadStatus;
  static double get downloadProgress => _downloadProgress;
  static int get receivedBytes => _receivedBytes;
  static int get totalBytes => _totalBytes;
  static String? get downloadedFilePath => _downloadedFilePath;
  static String get statusMessage => _statusMessage;
  static UpdateInfo? get latestUpdateInfo => _latestUpdateInfo;
  static bool get hasUpdate => _latestUpdateInfo != null;
  
  static void resetDownloadState() {
    _downloadStatus = DownloadStatus.idle;
    _downloadProgress = 0.0;
    _receivedBytes = 0;
    _totalBytes = 0;
    _downloadedFilePath = null;
    _statusMessage = '';
  }
  
  /// Compare semantic versions (e.g., "1.2.3" vs "1.2.4")
  /// Returns: -1 if v1 < v2, 0 if v1 == v2, 1 if v1 > v2
  static int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    
    final maxLength = parts1.length > parts2.length ? parts1.length : parts2.length;
    
    for (int i = 0; i < maxLength; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      
      if (p1 < p2) return -1;
      if (p1 > p2) return 1;
    }
    
    return 0;
  }
  
  /// Check if there's a new version available
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;
      
      debugPrint('UpdateService: Current version: $currentVersion ($currentVersionCode)');
      
      // Fetch version info from server
      final response = await http.get(Uri.parse(versionCheckUrl));
      
      if (response.statusCode != 200) {
        debugPrint('UpdateService: Failed to fetch version info: ${response.statusCode}');
        return null;
      }
      
      final jsonData = json.decode(response.body) as Map<String, dynamic>;
      final latestVersion = jsonData['version'] as String;
      final latestVersionCode = jsonData['versionCode'] as int;
      final downloadUrl = jsonData['downloadUrl'] as String;
      final updateLog = jsonData['updateLog'] as String;
      final forceUpdate = jsonData['forceUpdate'] as bool? ?? false;
      final fileSize = jsonData['fileSize'] as String? ?? '';
      
      debugPrint('UpdateService: Latest version: $latestVersion ($latestVersionCode)');
      
      // Compare versions using semantic versioning
      final hasUpdate = _compareVersions(currentVersion, latestVersion) < 0;
      
      if (hasUpdate) {
        final updateInfo = UpdateInfo(
          version: latestVersion,
          versionCode: latestVersionCode,
          downloadUrl: downloadUrl,
          updateLog: updateLog,
          forceUpdate: forceUpdate,
          fileSize: fileSize,
          currentVersion: currentVersion,
        );
        _latestUpdateInfo = updateInfo;
        return updateInfo;
      }
      
      _latestUpdateInfo = null;
      return null; // No update available
    } catch (e) {
      debugPrint('UpdateService: Error checking for update: $e');
      return null;
    }
  }
  
  /// Download APK file with progress callback
  static Future<String?> downloadApk(
    String url, {
    Function(int received, int total)? onProgress,
  }) async {
    try {
      // If already downloaded, return the file path
      if (_downloadStatus == DownloadStatus.completed && _downloadedFilePath != null) {
        final file = File(_downloadedFilePath!);
        if (await file.exists()) {
          debugPrint('UpdateService: Using cached download: $_downloadedFilePath');
          return _downloadedFilePath;
        }
      }
      
      // If currently downloading, wait for it to complete
      if (_downloadStatus == DownloadStatus.downloading) {
        debugPrint('UpdateService: Download already in progress');
        return null;
      }
      
      _downloadStatus = DownloadStatus.downloading;
      _downloadProgress = 0.0;
      _statusMessage = '正在下载更新...';
      
      debugPrint('UpdateService: Starting single-threaded download from $url');
      
      // Get external storage directory (persists across app restarts)
      final Directory? externalDir = await getExternalStorageDirectory();
      final dir = externalDir ?? await getTemporaryDirectory();
      final fileName = 'inter-knot-update.apk';
      final filePath = '${dir.path}/$fileName';
      
      // Delete old file if exists
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      return await _downloadSingleThreaded(url, filePath, onProgress);
    } catch (e) {
      debugPrint('UpdateService: Error downloading APK: $e');
      _downloadStatus = DownloadStatus.failed;
      _statusMessage = '下载失败：$e';
      return null;
    }
  }
  /// Single-threaded download implementation
  static Future<String?> _downloadSingleThreaded(
    String url,
    String filePath,
    Function(int received, int total)? onProgress,
  ) async {
    debugPrint('UpdateService: Using single-threaded download');
    
    final request = http.Request('GET', Uri.parse(url));
    final response = await request.send();
    
    if (response.statusCode != 200) {
      debugPrint('UpdateService: Download failed: ${response.statusCode}');
      _downloadStatus = DownloadStatus.failed;
      _statusMessage = '下载失败';
      return null;
    }
    
    _totalBytes = response.contentLength ?? 0;
    _receivedBytes = 0;
    
    final file = File(filePath);
    final sink = file.openWrite();
    
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        _receivedBytes += chunk.length;
        if (_totalBytes > 0) {
          _downloadProgress = _receivedBytes / _totalBytes;
          _statusMessage = '正在下载... ${(_receivedBytes / 1024 / 1024).toStringAsFixed(1)}MB / ${(_totalBytes / 1024 / 1024).toStringAsFixed(1)}MB';
        }
        onProgress?.call(_receivedBytes, _totalBytes);
      }
      
      await sink.close();
      debugPrint('UpdateService: Download completed: $filePath');
      _downloadStatus = DownloadStatus.completed;
      _downloadedFilePath = filePath;
      _statusMessage = '下载完成';
      
      return filePath;
    } catch (e) {
      await sink.close();
      debugPrint('UpdateService: Download stream error: $e');
      _downloadStatus = DownloadStatus.failed;
      _statusMessage = '下载失败：$e';
      return null;
    }
  }
  
  /// Install APK file
  static Future<bool> installApk(String filePath) async {
    try {
      debugPrint('UpdateService: Installing APK: $filePath');
      
      final result = await OpenFile.open(filePath);
      
      debugPrint('UpdateService: Install result: ${result.type} - ${result.message}');
      
      return result.type == ResultType.done;
    } catch (e) {
      debugPrint('UpdateService: Error installing APK: $e');
      return false;
    }
  }
}

/// Update information model
class UpdateInfo {
  final String version;
  final int versionCode;
  final String downloadUrl;
  final String updateLog;
  final bool forceUpdate;
  final String fileSize;
  final String currentVersion;
  
  UpdateInfo({
    required this.version,
    required this.versionCode,
    required this.downloadUrl,
    required this.updateLog,
    required this.forceUpdate,
    required this.fileSize,
    required this.currentVersion,
  });
}
