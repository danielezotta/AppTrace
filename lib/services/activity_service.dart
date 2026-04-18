import 'dart:async';
import '../database/repository.dart';
import '../models/activity_event.dart';
import 'native_bridge.dart';

class ActivityService {
  final ActivityRepository _repository = ActivityRepository();
  StreamSubscription? _windowStreamSubscription;
  StreamSubscription? _inputStreamSubscription;
  
  bool _isMonitoring = false;
  String? _currentProcess;
  String? _currentExecutablePath;
  String? _currentWindowTitle;
  int? _lastWindowChangeTime;
  
  // Input counts for current minute
  int _currentMinuteKeys = 0;
  int _currentMinuteClicks = 0;
  int _currentMinuteScrolls = 0;
  int? _currentMinuteTimestamp;
  Timer? _minuteAggregationTimer;

  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    try {
      // Check if recording is enabled
      final isRecording = await _repository.isRecording();
      if (!isRecording) return;

      _isMonitoring = true;
      _lastWindowChangeTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Start native monitoring (may not be available in debug)
      try {
        await NativeBridge.startWindowMonitoring();
        await NativeBridge.startInputMonitoring();

        // Listen to window changes
        _windowStreamSubscription =
            NativeBridge.getActiveWindowStream().listen(
          _onWindowChange,
          onError: (error) => print('Window stream error: $error'),
        );

        // Listen to input counts
        _inputStreamSubscription =
            NativeBridge.getInputCountsStream().listen(
          _onInputCount,
          onError: (error) => print('Input stream error: $error'),
        );
      } catch (e) {
        print('Native plugin not available: $e');
        // Continue without native monitoring for testing
      }

      // Start minute aggregation timer
      _startMinuteAggregation();

      print('Activity monitoring started');
    } catch (e) {
      _isMonitoring = false;
      print('Error starting activity monitoring: $e');
      rethrow;
    }
  }

  Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;

    try {
      _isMonitoring = false;

      // Cancel subscriptions
      await _windowStreamSubscription?.cancel();
      await _inputStreamSubscription?.cancel();
      _minuteAggregationTimer?.cancel();

      // Stop native monitoring
      await NativeBridge.stopWindowMonitoring();
      await NativeBridge.stopInputMonitoring();

      // Flush remaining input counts
      if (_currentMinuteKeys > 0 ||
          _currentMinuteClicks > 0 ||
          _currentMinuteScrolls > 0) {
        await _flushInputCounts();
      }

      print('Activity monitoring stopped');
    } catch (e) {
      print('Error stopping activity monitoring: $e');
      rethrow;
    }
  }

  Future<void> pauseRecording() async {
    await _repository.setRecording(false);
  }

  Future<void> resumeRecording() async {
    await _repository.setRecording(true);
  }

  bool get isMonitoring => _isMonitoring;

  void _onWindowChange(dynamic event) async {
    if (!_isMonitoring) return;

    try {
      final processName = event['processName'] as String?;
      final executablePath = event['executablePath'] as String?;
      final windowTitle = event['windowTitle'] as String?;

      if (processName == null) return;

      // Check if this process/window should be excluded
      if (await _isExcluded(processName, windowTitle)) {
        return;
      }

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // If we had a previous window, record its duration
      if (_currentProcess != null && _lastWindowChangeTime != null) {
        final duration = now - _lastWindowChangeTime!;
        if (duration > 0) {
          final event = ActiveWindowEvent(
            tsUtc: _lastWindowChangeTime!,
            processName: _currentProcess!,
            executablePath: _currentExecutablePath,
            windowTitle: _currentWindowTitle,
            durationMs: duration * 1000,
          );
          await _repository.insertActiveWindowEvent(event);
        }
      }

      _currentProcess = processName;
      _currentExecutablePath = executablePath;
      _currentWindowTitle = windowTitle;
      _lastWindowChangeTime = now;
    } catch (e) {
      print('Error processing window change: $e');
    }
  }

  void _onInputCount(dynamic event) async {
    if (!_isMonitoring) return;

    try {
      final keys = event['keys'] as int? ?? 0;
      final clicks = event['mouseClicks'] as int? ?? 0;
      final scrolls = event['mouseScrolls'] as int? ?? 0;

      _currentMinuteKeys += keys;
      _currentMinuteClicks += clicks;
      _currentMinuteScrolls += scrolls;
    } catch (e) {
      print('Error processing input count: $e');
    }
  }

  void _startMinuteAggregation() {
    _minuteAggregationTimer =
        Timer.periodic(Duration(minutes: 1), (_) async {
      await _flushInputCounts();
    });
  }

  Future<void> _flushInputCounts() async {
    if (_currentMinuteKeys == 0 &&
        _currentMinuteClicks == 0 &&
        _currentMinuteScrolls == 0) {
      return;
    }

    try {
      final timestamp = _currentMinuteTimestamp ??
          (DateTime.now().millisecondsSinceEpoch ~/ 1000);

      final event = InputCountEvent(
        tsUtc: timestamp,
        processName: _currentProcess ?? 'unknown',
        keys: _currentMinuteKeys,
        mouseClicks: _currentMinuteClicks,
        mouseScrolls: _currentMinuteScrolls,
      );

      await _repository.insertInputCountEvent(event);

      // Reset counters
      _currentMinuteKeys = 0;
      _currentMinuteClicks = 0;
      _currentMinuteScrolls = 0;
      _currentMinuteTimestamp = null;
    } catch (e) {
      print('Error flushing input counts: $e');
    }
  }

  Future<bool> _isExcluded(String processName, String? windowTitle) async {
    final exclusions = await _repository.getExclusions();

    for (final exclusion in exclusions) {
      final type = exclusion['type'];
      final pattern = exclusion['pattern'];

      if (type == 'process' && _matchesPattern(processName, pattern!)) {
        return true;
      }

      if (type == 'window_title' &&
          windowTitle != null &&
          _matchesPattern(windowTitle, pattern!)) {
        return true;
      }
    }

    return false;
  }

  bool _matchesPattern(String text, String pattern) {
    // Simple glob-like pattern matching
    if (pattern == '*') return true;
    if (pattern == text) return true;

    // Support * wildcards
    if (pattern.contains('*')) {
      final regexPattern = pattern
          .replaceAll('.', '\\.')
          .replaceAll('*', '.*');
      return RegExp('^$regexPattern\$', caseSensitive: false)
          .hasMatch(text);
    }

    return false;
  }

  /// Get timeline for a specific date
  Future<List<ActiveWindowEvent>> getTimeline(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay =
        startOfDay.add(Duration(days: 1)).subtract(Duration(seconds: 1));

    return _repository.getActiveWindowEvents(
      startDate: startOfDay,
      endDate: endOfDay,
    );
  }

  /// Get top apps for a specific date
  Future<List<DailyAggregate>> getTopApps(DateTime date) async {
    final dateStr = _formatDate(date);
    return _repository.getDailyAggregates(dateUtc: dateStr);
  }

  /// Get aggregates for a date range
  Future<List<DailyAggregate>> getAggregatesRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return _repository.getDailyAggregatesRange(
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Aggregate events for a specific date
  Future<void> aggregateDay(DateTime date) async {
    final dateStr = _formatDate(date);
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay =
        startOfDay.add(Duration(days: 1)).subtract(Duration(seconds: 1));

    final windowEvents = await _repository.getActiveWindowEvents(
      startDate: startOfDay,
      endDate: endOfDay,
    );

    final inputEvents = await _repository.getInputCountEvents(
      startDate: startOfDay,
      endDate: endOfDay,
    );

    // Group by process and track the most recent executable path
    final processMap = <String, _AggregateData>{};

    for (final event in windowEvents) {
      final existing = processMap[event.processName];
      if (existing != null) {
        processMap[event.processName] = _AggregateData(
          totalMs: existing.totalMs + event.durationMs,
          keys: existing.keys,
          mouseClicks: existing.mouseClicks,
          mouseScrolls: existing.mouseScrolls,
          executablePath: event.executablePath ?? existing.executablePath,
        );
      } else {
        processMap[event.processName] = _AggregateData(
          totalMs: event.durationMs,
          keys: 0,
          mouseClicks: 0,
          mouseScrolls: 0,
          executablePath: event.executablePath,
        );
      }
    }

    for (final event in inputEvents) {
      final existing = processMap[event.processName];
      if (existing != null) {
        processMap[event.processName] = _AggregateData(
          totalMs: existing.totalMs,
          keys: existing.keys + event.keys,
          mouseClicks: existing.mouseClicks + event.mouseClicks,
          mouseScrolls: existing.mouseScrolls + event.mouseScrolls,
          executablePath: existing.executablePath,
        );
      } else {
        processMap[event.processName] = _AggregateData(
          totalMs: 0,
          keys: event.keys,
          mouseClicks: event.mouseClicks,
          mouseScrolls: event.mouseScrolls,
          executablePath: null,
        );
      }
    }

    // Upsert aggregates
    for (final entry in processMap.entries) {
      final data = entry.value;
      await _repository.upsertDailyAggregate(DailyAggregate(
        dateUtc: dateStr,
        processName: entry.key,
        executablePath: data.executablePath,
        totalMs: data.totalMs,
        keys: data.keys,
        mouseClicks: data.mouseClicks,
        mouseScrolls: data.mouseScrolls,
      ));
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _AggregateData {
  final int totalMs;
  final int keys;
  final int mouseClicks;
  final int mouseScrolls;
  final String? executablePath;

  _AggregateData({
    required this.totalMs,
    required this.keys,
    required this.mouseClicks,
    required this.mouseScrolls,
    this.executablePath,
  });
}
