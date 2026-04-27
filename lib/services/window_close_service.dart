import 'package:window_manager/window_manager.dart';
import '../database/repository.dart';

class WindowCloseService with WindowListener {
  static final WindowCloseService _instance = WindowCloseService._internal();
  final ActivityRepository _repository = ActivityRepository();

  bool _isInitialized = false;
  bool _closeToTray = true;

  factory WindowCloseService() {
    return _instance;
  }

  WindowCloseService._internal();

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    _closeToTray = await _repository.isCloseToTrayEnabled();
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
    _isInitialized = true;
  }

  Future<void> refreshPreference() async {
    _closeToTray = await _repository.isCloseToTrayEnabled();
  }

  Future<void> exitApp() async {
    await windowManager.destroy();
  }

  @override
  void onWindowClose() async {
    if (_closeToTray) {
      await windowManager.hide();
      return;
    }

    await windowManager.destroy();
  }

  Future<void> dispose() async {
    if (!_isInitialized) {
      return;
    }

    windowManager.removeListener(this);
    _isInitialized = false;
  }
}