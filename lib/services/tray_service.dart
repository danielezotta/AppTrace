import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class TrayService with TrayListener {
  static final TrayService _instance = TrayService._internal();
  bool _isRecording = true;

  factory TrayService() {
    return _instance;
  }

  TrayService._internal();

  Future<void> initialize() async {
    trayManager.addListener(this);
    await _buildTrayMenu();
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
        windowManager.destroy();
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
