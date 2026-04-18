import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/activity_event.dart';
import 'database.dart';

class ActivityRepository {
  final DatabaseService _dbService = DatabaseService();

  Future<int> insertActiveWindowEvent(ActiveWindowEvent event) async {
    final db = await _dbService.database;
    return await db.insert('events_active_window', event.toMap());
  }

  Future<int> insertInputCountEvent(InputCountEvent event) async {
    final db = await _dbService.database;
    return await db.insert('events_input_counts', event.toMap());
  }

  Future<List<ActiveWindowEvent>> getActiveWindowEvents({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await _dbService.database;
    final startTs = startDate.millisecondsSinceEpoch ~/ 1000;
    final endTs = endDate.millisecondsSinceEpoch ~/ 1000;

    final result = await db.query(
      'events_active_window',
      where: 'ts_utc BETWEEN ? AND ?',
      whereArgs: [startTs, endTs],
      orderBy: 'ts_utc DESC',
    );

    return result.map((map) => ActiveWindowEvent.fromMap(map)).toList();
  }

  Future<List<InputCountEvent>> getInputCountEvents({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await _dbService.database;
    final startTs = startDate.millisecondsSinceEpoch ~/ 1000;
    final endTs = endDate.millisecondsSinceEpoch ~/ 1000;

    final result = await db.query(
      'events_input_counts',
      where: 'ts_utc BETWEEN ? AND ?',
      whereArgs: [startTs, endTs],
      orderBy: 'ts_utc DESC',
    );

    return result.map((map) => InputCountEvent.fromMap(map)).toList();
  }

  Future<List<DailyAggregate>> getDailyAggregates({
    required String dateUtc,
  }) async {
    final db = await _dbService.database;

    final result = await db.query(
      'aggregates_daily',
      where: 'date_utc = ?',
      whereArgs: [dateUtc],
      orderBy: 'total_ms DESC',
    );

    return result.map((map) => DailyAggregate.fromMap(map)).toList();
  }

  Future<List<DailyAggregate>> getDailyAggregatesRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await _dbService.database;
    final startDateStr = _formatDate(startDate);
    final endDateStr = _formatDate(endDate);

    final result = await db.query(
      'aggregates_daily',
      where: 'date_utc BETWEEN ? AND ?',
      whereArgs: [startDateStr, endDateStr],
      orderBy: 'date_utc DESC, total_ms DESC',
    );

    return result.map((map) => DailyAggregate.fromMap(map)).toList();
  }

  Future<void> upsertDailyAggregate(DailyAggregate aggregate) async {
    final db = await _dbService.database;
    await db.insert(
      'aggregates_daily',
      aggregate.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> deleteOldEvents({int daysToKeep = 90}) async {
    final db = await _dbService.database;
    final cutoffTs = (DateTime.now().subtract(Duration(days: daysToKeep)))
            .millisecondsSinceEpoch ~/
        1000;

    int deletedWindow = await db.delete(
      'events_active_window',
      where: 'ts_utc < ?',
      whereArgs: [cutoffTs],
    );

    int deletedInput = await db.delete(
      'events_input_counts',
      where: 'ts_utc < ?',
      whereArgs: [cutoffTs],
    );

    return deletedWindow + deletedInput;
  }

  Future<void> addExclusion({
    required String type, // 'process' or 'window_title'
    required String pattern,
  }) async {
    final db = await _dbService.database;
    await db.insert(
      'exclusions',
      {
        'type': type,
        'pattern': pattern,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<Map<String, String>>> getExclusions() async {
    final db = await _dbService.database;
    final result = await db.query('exclusions');
    return result.cast<Map<String, String>>();
  }

  Future<void> removeExclusion({
    required String type,
    required String pattern,
  }) async {
    final db = await _dbService.database;
    await db.delete(
      'exclusions',
      where: 'type = ? AND pattern = ?',
      whereArgs: [type, pattern],
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await _dbService.database;
    final result = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (result.isEmpty) return null;
    return result.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await _dbService.database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> isRecording() async {
    final value = await getSetting('is_recording');
    return value != 'false';
  }

  Future<void> setRecording(bool recording) async {
    await setSetting('is_recording', recording ? 'true' : 'false');
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
