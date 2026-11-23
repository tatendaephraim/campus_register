import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'database_schema.dart';

/// A singleton class to manage the application's database.
///
/// This class handles the initialization of the database, table creation,
/// and provides a single point of access to the database instance.
class DatabaseHelper {
  static const _databaseName = "CampusRegister.db";
  static const _databaseVersion = 12;

  // Make this a singleton class.
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  // Only have a single app-wide reference to the database.
  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initializes the database and creates tables if they don't exist.
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Version 12: intentional full reset for fresh user base.
  /// Drops every table (respecting FK order) and recreates the full schema.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (newVersion == 12) {
      // ── Full wipe: fresh start for new users ──────────────────────────────
      final batch = db.batch();
      batch.execute("DROP TABLE IF EXISTS timetable_day_overrides");
      batch.execute("DROP TABLE IF EXISTS attendance_waivers");
      batch.execute("DROP TABLE IF EXISTS clock_logs");
      batch.execute("DROP TABLE IF EXISTS attendance_records");
      batch.execute("DROP TABLE IF EXISTS course_students");
      batch.execute("DROP TABLE IF EXISTS timetable_slots");
      batch.execute("DROP TABLE IF EXISTS courses");
      batch.execute("DROP TABLE IF EXISTS venues");
      batch.execute("DROP TABLE IF EXISTS students");
      batch.execute("DROP TABLE IF EXISTS teachers");
      batch.execute("DROP TABLE IF EXISTS timetable_constraints");
      batch.execute("DROP TABLE IF EXISTS organizations");
      await batch.commit(noResult: true);
      await _onCreate(db, newVersion);
    } else {
      // ── Additive migrations for older incremental upgrades ────────────────
      if (oldVersion < 10) {
        try { await db.execute("ALTER TABLE venues ADD COLUMN category TEXT DEFAULT 'classroom'"); } catch (_) {}
        try { await db.execute("ALTER TABLE venues ADD COLUMN organization_id INTEGER"); } catch (_) {}
        try { await db.execute("ALTER TABLE teachers ADD COLUMN office_venue_id INTEGER"); } catch (_) {}
      }
      if (oldVersion < 11) {
        try { await db.execute("ALTER TABLE attendance_records ADD COLUMN checked_out_at TEXT"); } catch (_) {}
      }
      if (oldVersion < 12) {
        try { await db.execute(DatabaseSchema.createTimetableDayOverridesTable); } catch (_) {}
      }
    }
  }

  /// Executes the table creation scripts when the database is first created.
  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    batch.execute(DatabaseSchema.createOrganizationsTable);
    batch.execute(DatabaseSchema.createTimetableConstraintsTable);
    batch.execute(DatabaseSchema.createTeachersTable);
    batch.execute(DatabaseSchema.createCoursesTable);
    batch.execute(DatabaseSchema.createTimetableSlotsTable);
    batch.execute(DatabaseSchema.createStudentsTable);
    batch.execute(DatabaseSchema.createCourseStudentsTable);
    batch.execute(DatabaseSchema.createAttendanceRecordsTable);
    batch.execute(DatabaseSchema.createVenuesTable);
    batch.execute(DatabaseSchema.createClockLogsTable);
    batch.execute(DatabaseSchema.createAttendanceWaiversTable);
    batch.execute(DatabaseSchema.createTimetableDayOverridesTable);
    await batch.commit(noResult: true);
  }
}
