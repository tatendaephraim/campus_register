import 'database_helper.dart';
import 'student_attendance_view.dart';
import 'teacher_report_view.dart';

/// Repository for fetching attendance-related data.
class AttendanceRepository {
  final dbHelper = DatabaseHelper.instance;

  /// Fetches a comprehensive list of attendance records for a given student.
  ///
  /// This method performs a JOIN across `attendance_records`, `timetable_slots`,
  /// and `courses` to build a rich `StudentAttendanceView` object.
  Future<List<StudentAttendanceView>> getAttendanceForStudent(
      int studentId) async {
    final db = await dbHelper.database;
    const query = '''
      SELECT
        ar.id, ar.timestamp, ar.status,
        ts.day_of_week, ts.start_time, ts.end_time,
        c.name as course_name
      FROM attendance_records AS ar
      JOIN timetable_slots AS ts ON ar.timetable_slot_id = ts.id
      JOIN courses AS c ON ts.course_id = c.id
      WHERE ar.student_id = ?
      ORDER BY ar.timestamp DESC
    ''';

    final List<Map<String, dynamic>> maps =
        await db.rawQuery(query, [studentId]);

    return List.generate(maps.length, (i) {
      return StudentAttendanceView.fromMap(maps[i]);
    });
  }

  /// Fetches a historical attendance report for an entire course.
  Future<List<TeacherReportView>> getHistoricalReportForCourse(int courseId,
      {int? studentId, DateTime? startDate, DateTime? endDate}) async {
    final db = await dbHelper.database;

    List<String> whereClauses = ['ts.course_id = ?'];
    List<dynamic> whereArgs = [courseId];

    String query = '''
      SELECT
        ar.id,
        s.name as student_name,
        ar.timestamp,
        ar.status,
        ts.day_of_week,
        ts.start_time,
        ts.end_time
      FROM attendance_records AS ar
      JOIN students AS s ON ar.student_id = s.id
      JOIN timetable_slots AS ts ON ar.timetable_slot_id = ts.id
    ''';

    if (studentId != null) {
      whereClauses.add('s.id = ?');
      whereArgs.add(studentId);
    }
    if (startDate != null) {
      whereClauses.add('ar.timestamp >= ?');
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      // Add 1 day to the end date to include the entire day in the range.
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day)
          .add(const Duration(days: 1));
      whereClauses.add('ar.timestamp < ?');
      whereArgs.add(endOfDay.toIso8601String());
    }

    query +=
        ' WHERE ${whereClauses.join(' AND ')} ORDER BY ar.timestamp DESC, s.name ASC';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, whereArgs);

    return List.generate(
        maps.length, (i) => TeacherReportView.fromMap(maps[i]));
  }
}
