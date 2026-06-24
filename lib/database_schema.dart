/// Contains the SQL strings for creating the database tables.
///
/// This class centralizes the database schema definition, making it easier
/// to manage and version.
class DatabaseSchema {
  /// SQL statement to create the `teachers` table.
  static const String createTeachersTable = '''
  CREATE TABLE teachers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    google_sheet_url TEXT
  );
  ''';

  /// SQL statement to create the `courses` table.
  static const String createCoursesTable = '''
  CREATE TABLE courses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    teacher_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    school_name TEXT,
    start_date TEXT NOT NULL,
    end_date TEXT NOT NULL,
    venue_id INTEGER,
    FOREIGN KEY(teacher_id) REFERENCES teachers(id)
  );
  ''';

  /// SQL statement to create the `timetable_slots` table.
  static const String createTimetableSlotsTable = '''
  CREATE TABLE timetable_slots (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    course_id INTEGER NOT NULL,
    day_of_week INTEGER NOT NULL,
    start_time TEXT NOT NULL,
    end_time TEXT NOT NULL,
    FOREIGN KEY(course_id) REFERENCES courses(id)
  );
  ''';

  /// SQL statement to create the `students` table.
  static const String createStudentsTable = '''
  CREATE TABLE students (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    course_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    device_app_id TEXT UNIQUE NOT NULL,
    FOREIGN KEY(course_id) REFERENCES courses(id)
  );
  ''';

  /// SQL statement to create the `attendance_records` table.
  static const String createAttendanceRecordsTable = '''
  CREATE TABLE attendance_records (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id INTEGER NOT NULL,
    timetable_slot_id INTEGER NOT NULL,
    type TEXT NOT NULL,
    timestamp TEXT NOT NULL,
    status TEXT NOT NULL,
    location TEXT NOT NULL,
    altitude REAL NOT NULL,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    FOREIGN KEY(student_id) REFERENCES students(id),
    FOREIGN KEY(timetable_slot_id) REFERENCES timetable_slots(id)
  );
  ''';

  /// SQL statement to create the `venues` table for geofencing.
  static const String createVenuesTable = '''
  CREATE TABLE venues (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    altitude REAL NOT NULL,
    radius REAL NOT NULL,
    vertical_tolerance REAL NOT NULL,
    polygon_corners TEXT
  );
  ''';
}
