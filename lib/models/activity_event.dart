class ActiveWindowEvent {
  final int? id;
  final int tsUtc;
  final String processName;
  final String? executablePath;
  final String? windowTitle;
  final int durationMs;

  ActiveWindowEvent({
    this.id,
    required this.tsUtc,
    required this.processName,
    this.executablePath,
    this.windowTitle,
    required this.durationMs,
  });

  Map<String, dynamic> toMap() {
    return {
      'ts_utc': tsUtc,
      'process_name': processName,
      'executable_path': executablePath,
      'window_title': windowTitle,
      'duration_ms': durationMs,
    };
  }

  factory ActiveWindowEvent.fromMap(Map<String, dynamic> map) {
    return ActiveWindowEvent(
      id: map['id'] as int?,
      tsUtc: map['ts_utc'] as int,
      processName: map['process_name'] as String,
      executablePath: map['executable_path'] as String?,
      windowTitle: map['window_title'] as String?,
      durationMs: map['duration_ms'] as int,
    );
  }
}

class InputCountEvent {
  final int? id;
  final int tsUtc;
  final String processName;
  final int keys;
  final int mouseClicks;
  final int mouseScrolls;

  InputCountEvent({
    this.id,
    required this.tsUtc,
    required this.processName,
    required this.keys,
    required this.mouseClicks,
    required this.mouseScrolls,
  });

  Map<String, dynamic> toMap() {
    return {
      'ts_utc': tsUtc,
      'process_name': processName,
      'keys': keys,
      'mouse_clicks': mouseClicks,
      'mouse_scrolls': mouseScrolls,
    };
  }

  factory InputCountEvent.fromMap(Map<String, dynamic> map) {
    return InputCountEvent(
      id: map['id'] as int?,
      tsUtc: map['ts_utc'] as int,
      processName: map['process_name'] as String,
      keys: map['keys'] as int? ?? 0,
      mouseClicks: map['mouse_clicks'] as int? ?? 0,
      mouseScrolls: map['mouse_scrolls'] as int? ?? 0,
    );
  }
}

class DailyAggregate {
  final int? id;
  final String dateUtc;
  final String processName;
  final String? executablePath;
  final int totalMs;
  final int keys;
  final int mouseClicks;
  final int mouseScrolls;

  DailyAggregate({
    this.id,
    required this.dateUtc,
    required this.processName,
    this.executablePath,
    required this.totalMs,
    required this.keys,
    required this.mouseClicks,
    required this.mouseScrolls,
  });

  Map<String, dynamic> toMap() {
    return {
      'date_utc': dateUtc,
      'process_name': processName,
      'executable_path': executablePath,
      'total_ms': totalMs,
      'keys': keys,
      'mouse_clicks': mouseClicks,
      'mouse_scrolls': mouseScrolls,
    };
  }

  factory DailyAggregate.fromMap(Map<String, dynamic> map) {
    return DailyAggregate(
      id: map['id'] as int?,
      dateUtc: map['date_utc'] as String,
      processName: map['process_name'] as String,
      executablePath: map['executable_path'] as String?,
      totalMs: map['total_ms'] as int? ?? 0,
      keys: map['keys'] as int? ?? 0,
      mouseClicks: map['mouse_clicks'] as int? ?? 0,
      mouseScrolls: map['mouse_scrolls'] as int? ?? 0,
    );
  }
}
