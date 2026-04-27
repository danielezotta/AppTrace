import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'window_close_service.dart';

class TrayService with TrayListener {
  static final TrayService _instance = TrayService._internal();
  bool _isRecording = true;

  factory TrayService() {
    return _instance;
  }

  TrayService._internal();

  Future<void> initialize() async {
    trayManager.addListener(this);
    await _setTrayIcon();
    await trayManager.setToolTip('AppTrace');
    await _buildTrayMenu();
  }

  Future<void> _setTrayIcon() async {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final iconCandidates = [
      '$exeDir/data/flutter_assets/assets/icons/tray_icon.ico',
      '$exeDir/resources/app_icon.ico',
      File('windows/runner/resources/app_icon.ico').absolute.path,
    ];

    for (final iconPath in iconCandidates) {
      if (!File(iconPath).existsSync()) {
        continue;
      }

      await trayManager.setIcon(iconPath);
      return;
    }
  }

  Future<void> _buildTrayMenu() async {
    final menu = Menu(
      items: [
        MenuItem(
          key: 'show',
          label: 'Show',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'toggle_recording',
          label: _isRecording ? 'Pause Recording' : 'Resume Recording',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'exit',
          label: 'Exit',
        ),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        windowManager.show();
        break;
      case 'toggle_recording':
        _isRecording = !_isRecording;
        _buildTrayMenu();
        break;
      case 'exit':
        WindowCloseService().exitApp();
        break;
    }
  }

  bool get isRecording => _isRecording;

  Future<void> setRecording(bool recording) async {
    _isRecording = recording;
    await _buildTrayMenu();
  }

  Future<void> dispose() async {
    trayManager.removeListener(this);
  }
}
