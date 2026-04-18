import 'dart:io';
import 'package:path/path.dart' as path;
import '../database/repository.dart';

class ExportService {
  final ActivityRepository _repository = ActivityRepository();

  /// Export daily aggregates to CSV
  Future<String> exportDailyAggregates({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final aggregates = await _repository.getDailyAggregatesRange(
      startDate: startDate,
      endDate: endDate,
    );

    final buffer = StringBuffer();

    // Write header
    buffer.writeln(
      'Date,Process Name,Total Time (hours),Keyboard Inputs,Mouse Clicks,Mouse Scrolls',
    );

    // Write data
    for (final agg in aggregates) {
      final hours = agg.totalMs / (1000 * 60 * 60);
      buffer.writeln(
        '${agg.dateUtc},"${_escapeCsv(agg.processName)}",${hours.toStringAsFixed(2)},${agg.keys},${agg.mouseClicks},${agg.mouseScrolls}',
      );
    }

    return buffer.toString();
  }

  /// Export timeline events to CSV
  Future<String> exportTimeline({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final events = await _repository.getActiveWindowEvents(
      startDate: startDate,
      endDate: endDate,
    );

    final buffer = StringBuffer();

    // Write header
    buffer.writeln(
      'Timestamp,Process Name,Window Title,Duration (seconds)',
    );

    // Write data
    for (final event in events) {
      final dateTime =
          DateTime.fromMillisecondsSinceEpoch(event.tsUtc * 1000);
      final duration = event.durationMs / 1000;
      buffer.writeln(
        '${dateTime.toIso8601String()},"${_escapeCsv(event.processName)}","${_escapeCsv(event.windowTitle ?? '')}",${duration.toStringAsFixed(2)}',
      );
    }

    return buffer.toString();
  }

  /// Save CSV to file
  Future<String> saveToFile(String csvContent, String filename) async {
    final downloadsPath = _getDownloadsPath();
    final filePath = path.join(downloadsPath, filename);

    final file = File(filePath);
    await file.writeAsString(csvContent);

    return filePath;
  }

  /// Export and save in one operation
  Future<String> exportAndSaveDailyAggregates({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final csv = await exportDailyAggregates(
      startDate: startDate,
      endDate: endDate,
    );

    final filename =
        'apptrace_daily_${_formatDate(startDate)}_to_${_formatDate(endDate)}.csv';

    return saveToFile(csv, filename);
  }

  /// Export and save timeline
  Future<String> exportAndSaveTimeline({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final csv = await exportTimeline(
      startDate: startDate,
      endDate: endDate,
    );

    final filename =
        'apptrace_timeline_${_formatDate(startDate)}_to_${_formatDate(endDate)}.csv';

    return saveToFile(csv, filename);
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _getDownloadsPath() {
    final appData = Platform.environment['APPDATA'] ?? '';
    final userProfile = Platform.environment['USERPROFILE'] ?? '';

    // Try common Downloads locations
    final downloadsPath = path.join(userProfile, 'Downloads');
    if (Directory(downloadsPath).existsSync()) {
      return downloadsPath;
    }

    // Fallback to AppData
    return path.join(appData, 'AppTrace', 'exports');
  }
}
