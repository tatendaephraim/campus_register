import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'database_schema.dart';

/// A singleton class to manage the application's database.
///
/// This class handles the initialization of the database, table creation,
/// and provides a single point of access to the database instance.
class DatabaseHelper {
  static const _databaseName = "CampusRegister.db";
  static const _databaseVersion = 3;

  // Make this a singleton class.
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  // Only have a single app-wide reference to the database.
  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    // Lazily instantiate the db the first time it is accessed.
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

  /// Drops and recreates the database tables when version is upgraded.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    final batch = db.batch();
    batch.execute("DROP TABLE IF EXISTS teachers");
    batch.execute("DROP TABLE IF EXISTS courses");
    batch.execute("DROP TABLE IF EXISTS timetable_slots");
    batch.execute("DROP TABLE IF EXISTS students");
    batch.execute("DROP TABLE IF EXISTS attendance_records");
    batch.execute("DROP TABLE IF EXISTS venues");
    await batch.commit(noResult: true);
    await _onCreate(db, newVersion);
  }

  /// Executes the table creation scripts when the database is first created.
  Future<void> _onCreate(Database db, int version) async {
    // Use a batch to execute all table creation statements in a single transaction.
    final batch = db.batch();
    batch.execute(DatabaseSchema.createTeachersTable);
    batch.execute(DatabaseSchema.createCoursesTable);
    batch.execute(DatabaseSchema.createTimetableSlotsTable);
    batch.execute(DatabaseSchema.createStudentsTable);
    batch.execute(DatabaseSchema.createAttendanceRecordsTable);
    batch.execute(DatabaseSchema.createVenuesTable);
    await batch.commit(noResult: true);
  }
}
