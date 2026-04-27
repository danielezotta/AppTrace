import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

class UpdateInfo {
  final String latestVersion;
  final String releaseNotes;
  final String installerName;
  final String installerUrl;

  const UpdateInfo({
    required this.latestVersion,
    required this.releaseNotes,
    required this.installerName,
    required this.installerUrl,
  });
}

class UpdateService {
  final String owner;
  final String repository;

  const UpdateService({
    required this.owner,
    required this.repository,
  });

  Future<UpdateInfo?> checkForUpdate() async {
    if (!Platform.isWindows || owner.isEmpty || repository.isEmpty) {
      return null;
    }

    final currentVersion = await _getCurrentVersion();
    final release = await _fetchLatestRelease();
    if (release == null) {
      return null;
    }

    if (_compareVersions(release.latestVersion, currentVersion) <= 0) {
      return null;
    }

    return release;
  }

  Future<File> downloadInstaller(UpdateInfo updateInfo) async {
    final httpClient = HttpClient();
    try {
      final request = await httpClient.getUrl(Uri.parse(updateInfo.installerUrl));
      request.headers.set(HttpHeaders.userAgentHeader, 'AppTraceUpdater/1.0');
      request.headers.set(HttpHeaders.acceptHeader, 'application/octet-stream');

      final response = await request.close();
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to download installer (${response.statusCode})',
        );
      }

      final tempDir = await Directory.systemTemp.createTemp('apptrace_update_');
      final filePath = '${tempDir.path}\\${updateInfo.installerName}';
      final file = File(filePath);
      final bytes = await response.fold<List<int>>(
        <int>[],
        (previous, element) => previous..addAll(element),
      );
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } finally {
      httpClient.close();
    }
  }

  Future<void> launchInstaller(File installerFile) async {
    await Process.start(
      installerFile.path,
      const [],
      mode: ProcessStartMode.detached,
    );
  }

  Future<UpdateInfo?> _fetchLatestRelease() async {
    final httpClient = HttpClient();
    try {
      final url = Uri.parse(
        'https://api.github.com/repos/$owner/$repository/releases/latest',
      );
      final request = await httpClient.getUrl(url);
      request.headers.set(HttpHeaders.userAgentHeader, 'AppTraceUpdater/1.0');
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');

      final response = await request.close();
      if (response.statusCode != 200) {
        return null;
      }

      final payload = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(payload) as Map<String, dynamic>;

      final tagName = (decoded['tag_name'] as String? ?? '').trim();
      final latestVersion = _normalizeVersion(tagName);
      if (latestVersion.isEmpty) {
        return null;
      }

      final assets = (decoded['assets'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final installer = assets.firstWhere(
        (asset) {
          final name = (asset['name'] as String? ?? '').toLowerCase();
          return name.endsWith('.exe') && name.contains('setup');
        },
        orElse: () {
          return assets.firstWhere(
            (asset) =>
                (asset['name'] as String? ?? '').toLowerCase().endsWith('.exe'),
            orElse: () => <String, dynamic>{},
          );
        },
      );

      final installerName = installer['name'] as String?;
      final installerUrl = installer['browser_download_url'] as String?;
      if (installerName == null || installerUrl == null) {
        return null;
      }

      return UpdateInfo(
        latestVersion: latestVersion,
        releaseNotes: (decoded['body'] as String?)?.trim() ?? '',
        installerName: installerName,
        installerUrl: installerUrl,
      );
    } finally {
      httpClient.close();
    }
  }

  Future<String> _getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return _normalizeVersion(packageInfo.version);
  }

  String _normalizeVersion(String version) {
    final cleaned = version.trim();
    if (cleaned.startsWith('v') || cleaned.startsWith('V')) {
      return cleaned.substring(1);
    }
    return cleaned;
  }

  int _compareVersions(String left, String right) {
    final leftParts = _parseVersion(left);
    final rightParts = _parseVersion(right);

    for (var i = 0; i < 3; i++) {
      if (leftParts[i] > rightParts[i]) {
        return 1;
      }
      if (leftParts[i] < rightParts[i]) {
        return -1;
      }
    }
    return 0;
  }

  List<int> _parseVersion(String version) {
    final stable = version.split('-').first.split('+').first;
    final parts = stable.split('.');
    final parsed = <int>[0, 0, 0];
    for (var i = 0; i < parts.length && i < 3; i++) {
      parsed[i] = int.tryParse(parts[i]) ?? 0;
    }
    return parsed;
  }
}
