/// Contains the SQL strings for creating the database tables.
///
/// This class centralizes the database schema definition, making it easier
/// to manage and version.
class DatabaseSchema {
  /// SQL statement to create the `organizations` table.
  static const String createOrganizationsTable = '''
  CREATE TABLE organizations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    address TEXT,
    country TEXT,
    type TEXT NOT NULL,
    code TEXT UNIQUE NOT NULL
  );
  ''';

  /// SQL statement to create the `timetable_constraints` table.
  static const String createTimetableConstraintsTable = '''
  CREATE TABLE timetable_constraints (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    organization_id INTEGER UNIQUE NOT NULL,
    start_time TEXT NOT NULL,
    end_time TEXT NOT NULL,
    break_start TEXT,
    break_duration_mins INTEGER,
    lunch_start TEXT,
    lunch_duration_mins INTEGER,
    assembly_start TEXT,
    assembly_duration_mins INTEGER,
    FOREIGN KEY(organization_id) REFERENCES organizations(id) ON DELETE CASCADE
  );
  ''';

  /// SQL statement to create the `teachers` table.
  static const String createTeachersTable = '''
  CREATE TABLE teachers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    organization_id INTEGER,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    google_sheet_url TEXT,
    role TEXT DEFAULT 'teacher',
    is_approved INTEGER DEFAULT 0,
    device_app_id TEXT,
    office_venue_id INTEGER,
    FOREIGN KEY(organization_id) REFERENCES organizations(id) ON DELETE SET NULL,
    FOREIGN KEY(office_venue_id) REFERENCES venues(id) ON DELETE SET NULL
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
    FOREIGN KEY(teacher_id) REFERENCES teachers(id) ON DELETE CASCADE
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
    FOREIGN KEY(course_id) REFERENCES courses(id) ON DELETE CASCADE
  );
  ''';

  /// SQL statement to create the `students` table.
  static const String createStudentsTable = '''
  CREATE TABLE students (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    organization_id INTEGER,
    name TEXT NOT NULL,
    email TEXT UNIQUE,
    device_app_id TEXT NOT NULL,
    is_approved INTEGER DEFAULT 0,
    FOREIGN KEY(organization_id) REFERENCES organizations(id) ON DELETE SET NULL
  );
  ''';

  /// SQL statement to create the `course_students` junction table.
  static const String createCourseStudentsTable = '''
  CREATE TABLE course_students (
    course_id INTEGER NOT NULL,
    student_id INTEGER NOT NULL,
    PRIMARY KEY (course_id, student_id),
    FOREIGN KEY(course_id) REFERENCES courses(id) ON DELETE CASCADE,
    FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE
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
    checked_out_at TEXT,
    FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE,
    FOREIGN KEY(timetable_slot_id) REFERENCES timetable_slots(id) ON DELETE CASCADE
  );
  ''';

  /// SQL statement to create the `venues` table for geofencing.
  static const String createVenuesTable = '''
  CREATE TABLE venues (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    organization_id INTEGER,
    name TEXT NOT NULL,
    category TEXT DEFAULT 'classroom',
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    altitude REAL NOT NULL,
    radius REAL NOT NULL,
    vertical_tolerance REAL NOT NULL,
    polygon_corners TEXT,
    FOREIGN KEY(organization_id) REFERENCES organizations(id) ON DELETE CASCADE
  );
  ''';

  /// SQL statement to create the `clock_logs` table.
  static const String createClockLogsTable = '''
  CREATE TABLE clock_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    teacher_id INTEGER,
    student_id INTEGER,
    type TEXT NOT NULL,
    venue_id INTEGER,
    clock_in TEXT NOT NULL,
    clock_out TEXT,
    early_leave_reason TEXT,
    early_leave_approved INTEGER DEFAULT 0,
    FOREIGN KEY(teacher_id) REFERENCES teachers(id) ON DELETE CASCADE,
    FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE,
    FOREIGN KEY(venue_id) REFERENCES venues(id) ON DELETE CASCADE
  );
  ''';

  /// SQL statement to create the `attendance_waivers` table.
  static const String createAttendanceWaiversTable = '''
  CREATE TABLE attendance_waivers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id INTEGER,
    teacher_id INTEGER,
    date TEXT NOT NULL,
    reason TEXT NOT NULL,
    has_medical_proof INTEGER DEFAULT 0,
    approved_by_id INTEGER,
    FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE,
    FOREIGN KEY(teacher_id) REFERENCES teachers(id) ON DELETE CASCADE
  );
  ''';

  /// SQL statement to create the `timetable_day_overrides` table.
  /// Stores per-day working status and optional custom hours for each org.
  /// day_of_week: 1=Monday … 7=Sunday (Dart DateTime.weekday convention).
  static const String createTimetableDayOverridesTable = '''
  CREATE TABLE IF NOT EXISTS timetable_day_overrides (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    organization_id INTEGER NOT NULL,
    day_of_week INTEGER NOT NULL,
    is_working_day INTEGER DEFAULT 1,
    custom_start_time TEXT,
    custom_end_time TEXT,
    label TEXT,
    UNIQUE(organization_id, day_of_week),
    FOREIGN KEY(organization_id) REFERENCES organizations(id) ON DELETE CASCADE
  );
  ''';
}
