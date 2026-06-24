/// A read-only model representing a student's attendance record for display.
///
/// This model combines data from `attendance_records`, `timetable_slots`,
/// and `courses` tables for a comprehensive view.
class StudentAttendanceView {
  final int recordId;
  final DateTime timestamp;
  final String status;
  final String courseName;
  final int dayOfWeek;
  final String startTime;
  final String endTime;

  StudentAttendanceView({
    required this.recordId,
    required this.timestamp,
    required this.status,
    required this.courseName,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  /// Creates an instance from a map (typically from a database query).
  factory StudentAttendanceView.fromMap(Map<String, dynamic> map) {
    return StudentAttendanceView(
      recordId: map['id'] as int,
      timestamp: DateTime.parse(map['timestamp'] as String),
      status: map['status'] as String,
      courseName: map['course_name'] as String,
      dayOfWeek: map['day_of_week'] as int,
      startTime: map['start_time'] as String,
      endTime: map['end_time'] as String,
    );
  }
}
