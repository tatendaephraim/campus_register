import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/attendance_record.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('attendance.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        location TEXT NOT NULL,
        altitude REAL NOT NULL,
        estimatedFloor INTEGER NOT NULL,
        venueName TEXT NOT NULL,
        venueDescription TEXT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL
      )
    ''');

    // Create index for faster queries
    await db.execute('''
      CREATE INDEX idx_timestamp ON attendance(timestamp DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_venue ON attendance(venueName)
    ''');

    await db.execute('''
      CREATE INDEX idx_name ON attendance(name)
    ''');
  }

  // Insert attendance record
  Future<int> insertAttendance(AttendanceRecord record) async {
    final db = await database;
    final id = await db.insert('attendance', record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    print(
        '📊 Saved attendance record to database: ID=$id, ${record.toString()}');
    return id;
  }

  // Get all attendance records
  Future<List<AttendanceRecord>> getAllAttendance() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance',
      orderBy: 'timestamp DESC',
    );

    return maps.map((map) => AttendanceRecord.fromMap(map)).toList();
  }

  // Get attendance records by date range
  Future<List<AttendanceRecord>> getAttendanceByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'timestamp DESC',
    );

    return maps.map((map) => AttendanceRecord.fromMap(map)).toList();
  }

  // Get attendance records by venue
  Future<List<AttendanceRecord>> getAttendanceByVenue(String venueName) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance',
      where: 'venueName = ?',
      whereArgs: [venueName],
      orderBy: 'timestamp DESC',
    );

    return maps.map((map) => AttendanceRecord.fromMap(map)).toList();
  }

  // Get attendance records by user
  Future<List<AttendanceRecord>> getAttendanceByUser(String userName) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance',
      where: 'name = ?',
      whereArgs: [userName],
      orderBy: 'timestamp DESC',
    );

    return maps.map((map) => AttendanceRecord.fromMap(map)).toList();
  }

  // Get recent attendance records (last N records)
  Future<List<AttendanceRecord>> getRecentAttendance(int limit) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance',
      orderBy: 'timestamp DESC',
      limit: limit,
    );

    return maps.map((map) => AttendanceRecord.fromMap(map)).toList();
  }

  // Get attendance count by venue
  Future<Map<String, int>> getAttendanceCountByVenue() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT venueName, COUNT(*) as count
      FROM attendance
      GROUP BY venueName
      ORDER BY count DESC
    ''');

    return {
      for (var row in result) row['venueName'] as String: row['count'] as int
    };
  }

  // Delete attendance record
  Future<int> deleteAttendance(int id) async {
    final db = await database;
    return await db.delete(
      'attendance',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Delete all attendance records
  Future<int> deleteAllAttendance() async {
    final db = await database;
    return await db.delete('attendance');
  }

  // Get total count
  Future<int> getTotalCount() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM attendance');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
