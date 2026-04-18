import 'dart:async';
import 'package:flutter/services.dart';

class NativeBridge {
  static const platform = MethodChannel('com.apptrace/native');
  
  // Stream controllers for event delivery
  static final _activeWindowController = StreamController<dynamic>.broadcast();
  static final _inputCountsController = StreamController<dynamic>.broadcast();
  
  static bool _initialized = false;

  /// Initialize the native bridge and set up method call handlers
  static void initialize() {
    if (_initialized) return;
    
    platform.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onActiveWindowChanged':
          _activeWindowController.add(call.arguments);
          break;
        case 'onInputCounts':
          _inputCountsController.add(call.arguments);
          break;
        default:
          print('Unknown method from native: ${call.method}');
      }
    });
    
    _initialized = true;
  }

  /// Start monitoring foreground window changes
  static Future<void> startWindowMonitoring() async {
    initialize();
    try {
      await platform.invokeMethod('startWindowMonitoring');
    } catch (e) {
      print('Error starting window monitoring: $e');
      rethrow;
    }
  }

  /// Stop monitoring foreground window changes
  static Future<void> stopWindowMonitoring() async {
    try {
      await platform.invokeMethod('stopWindowMonitoring');
    } catch (e) {
      print('Error stopping window monitoring: $e');
      rethrow;
    }
  }

  /// Start monitoring input (keyboard and mouse)
  static Future<void> startInputMonitoring() async {
    initialize();
    try {
      await platform.invokeMethod('startInputMonitoring');
    } catch (e) {
      print('Error starting input monitoring: $e');
      rethrow;
    }
  }

  /// Stop monitoring input
  static Future<void> stopInputMonitoring() async {
    try {
      await platform.invokeMethod('stopInputMonitoring');
    } catch (e) {
      print('Error stopping input monitoring: $e');
      rethrow;
    }
  }

  /// Get stream of active window changes
  /// Emits: {processName: String, executablePath: String, windowTitle: String, timestamp: int}
  static Stream<dynamic> getActiveWindowStream() {
    initialize();
    return _activeWindowController.stream;
  }

  /// Get stream of input counts
  /// Emits: {keys: int, mouseClicks: int, mouseScrolls: int, timestamp: int}
  static Stream<dynamic> getInputCountsStream() {
    initialize();
    return _inputCountsController.stream;
  }
}
