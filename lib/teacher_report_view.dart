/// A read-only model representing a historical attendance record for the teacher's report.
class TeacherReportView {
  final int recordId;
  final String studentName;
  final DateTime timestamp;
  final String status;
  final int dayOfWeek;
  final String startTime;
  final String endTime;

  TeacherReportView({
    required this.recordId,
    required this.studentName,
    required this.timestamp,
    required this.status,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  /// Creates an instance from a map (typically from a database query).
  factory TeacherReportView.fromMap(Map<String, dynamic> map) {
    return TeacherReportView(
      recordId: map['id'] as int,
      studentName: map['student_name'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      status: map['status'] as String,
      dayOfWeek: map['day_of_week'] as int,
      startTime: map['start_time'] as String,
      endTime: map['end_time'] as String,
    );
  }
}
