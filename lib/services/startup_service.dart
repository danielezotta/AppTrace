import 'dart:io';

class StartupService {
  static const String _regPath =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const String _valueName = 'AppTrace';

  Future<void> syncWithSetting(bool shouldEnable) async {
    if (!Platform.isWindows) {
      return;
    }

    final currentlyEnabled = await isEnabled();
    if (currentlyEnabled == shouldEnable) {
      return;
    }

    await setEnabled(shouldEnable);
  }

  Future<bool> isEnabled() async {
    if (!Platform.isWindows) {
      return false;
    }

    final result = await Process.run('reg', [
      'query',
      _regPath,
      '/v',
      _valueName,
    ]);

    return result.exitCode == 0;
  }

  Future<void> setEnabled(bool enabled) async {
    if (!Platform.isWindows) {
      return;
    }

    if (enabled) {
      final exePath = Platform.resolvedExecutable;
      final command = '"$exePath"';
      final result = await Process.run('reg', [
        'add',
        _regPath,
        '/v',
        _valueName,
        '/t',
        'REG_SZ',
        '/d',
        command,
        '/f',
      ]);

      if (result.exitCode != 0) {
        throw Exception('Failed to enable start on login: ${result.stderr}');
      }
      return;
    }

    final result = await Process.run('reg', [
      'delete',
      _regPath,
      '/v',
      _valueName,
      '/f',
    ]);

    // Missing key/value is not an error for disable.
    final stdoutLower = result.stdout.toString().toLowerCase();
    if (result.exitCode != 0 &&
        !stdoutLower.contains('unable to find')) {
      throw Exception('Failed to disable start on login: ${result.stderr}');
    }
  }
}
