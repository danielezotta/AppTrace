import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    sqfliteFfiInit();
    final databaseFactory = databaseFactoryFfi;

    final dbPath = path.join(
      Platform.environment['APPDATA'] ?? '',
      'AppTrace',
      'apptrace.db',
    );

    // Ensure directory exists
    final dbDir = Directory(path.dirname(dbPath));
    if (!dbDir.existsSync()) {
      dbDir.createSync(recursive: true);
    }

    return await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 5,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Active window events table
    await db.execute('''
      CREATE TABLE events_active_window (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ts_utc INTEGER NOT NULL,
        process_name TEXT NOT NULL,
        executable_path TEXT,
        window_title TEXT,
        duration_ms INTEGER NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Input counts table (bucketed per minute)
    await db.execute('''
      CREATE TABLE events_input_counts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ts_utc INTEGER NOT NULL,
        process_name TEXT NOT NULL,
        keys INTEGER DEFAULT 0,
        mouse_clicks INTEGER DEFAULT 0,
        mouse_scrolls INTEGER DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Daily aggregates table
    await db.execute('''
      CREATE TABLE aggregates_daily (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date_utc TEXT NOT NULL,
        process_name TEXT NOT NULL,
        executable_path TEXT,
        total_ms INTEGER DEFAULT 0,
        keys INTEGER DEFAULT 0,
        mouse_clicks INTEGER DEFAULT 0,
        mouse_scrolls INTEGER DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(date_utc, process_name)
      )
    ''');

    // Exclusion list table
    await db.execute('''
      CREATE TABLE exclusions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        pattern TEXT NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(type, pattern)
      )
    ''');

    // Settings table
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Create indexes
    await db.execute(
      'CREATE INDEX idx_events_active_window_ts ON events_active_window(ts_utc)',
    );
    await db.execute(
      'CREATE INDEX idx_events_active_window_process ON events_active_window(process_name)',
    );
    await db.execute(
      'CREATE INDEX idx_events_input_counts_ts ON events_input_counts(ts_utc)',
    );
    await db.execute(
      'CREATE INDEX idx_aggregates_daily_date ON aggregates_daily(date_utc)',
    );
    await db.execute(
      'CREATE INDEX idx_aggregates_daily_process ON aggregates_daily(process_name)',
    );

    // Initialize default settings
    await db.insert('settings', {
      'key': 'is_recording',
      'value': 'true',
    });
    await db.insert('settings', {
      'key': 'record_keystroke_content',
      'value': 'false',
    });
    await db.insert('settings', {
      'key': 'start_on_login',
      'value': 'false',
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add executable_path column to events_active_window table
      await db.execute(
        'ALTER TABLE events_active_window ADD COLUMN executable_path TEXT',
      );
    }
    if (oldVersion < 3) {
      // Add executable_path column to aggregates_daily table
      await db.execute(
        'ALTER TABLE aggregates_daily ADD COLUMN executable_path TEXT',
      );
    }
    if (oldVersion < 4) {
      // Fix unknown process names by extracting from executable_path
      await _fixUnknownProcessNames(db);
    }
    if (oldVersion < 5) {
      await db.insert('settings', {
        'key': 'start_on_login',
        'value': 'false',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _fixUnknownProcessNames(Database db) async {
    // Fix events_active_window table
    final windowEvents = await db.query(
      'events_active_window',
      where: 'process_name = ? AND executable_path IS NOT NULL',
      whereArgs: ['unknown'],
    );

    for (final event in windowEvents) {
      final exePath = event['executable_path'] as String?;
      if (exePath != null && exePath.isNotEmpty) {
        final processName = _extractProcessNameFromPath(exePath);
        await db.update(
          'events_active_window',
          {'process_name': processName},
          where: 'id = ?',
          whereArgs: [event['id']],
        );
      }
    }

    // Fix aggregates_daily table
    final aggregates = await db.query(
      'aggregates_daily',
      where: 'process_name = ? AND executable_path IS NOT NULL',
      whereArgs: ['unknown'],
    );

    for (final agg in aggregates) {
      final exePath = agg['executable_path'] as String?;
      if (exePath != null && exePath.isNotEmpty) {
        final processName = _extractProcessNameFromPath(exePath);
        // Delete old record and insert with correct process_name
        await db.delete(
          'aggregates_daily',
          where: 'id = ?',
          whereArgs: [agg['id']],
        );
        await db.insert('aggregates_daily', {
          'date_utc': agg['date_utc'],
          'process_name': processName,
          'executable_path': exePath,
          'total_ms': agg['total_ms'],
          'keys': agg['keys'],
          'mouse_clicks': agg['mouse_clicks'],
          'mouse_scrolls': agg['mouse_scrolls'],
        });
      }
    }

    // Fix events_input_counts table (no executable_path, delete unknown records)
    await db.delete(
      'events_input_counts',
      where: 'process_name = ?',
      whereArgs: ['unknown'],
    );
  }

  String _extractProcessNameFromPath(String path) {
    final lastSlash = path.lastIndexOf('\\');
    if (lastSlash != -1) {
      return path.substring(lastSlash + 1);
    }
    final lastForwardSlash = path.lastIndexOf('/');
    if (lastForwardSlash != -1) {
      return path.substring(lastForwardSlash + 1);
    }
    return path;
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
