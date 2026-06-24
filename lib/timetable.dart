/// Represents a recurring time slot in a course's weekly schedule.
class TimetableSlot {
  final int? id;
  final int courseId;
  final int dayOfWeek; // 1 for Monday, 7 for Sunday
  final String startTime; // "HH:MM"
  final String endTime; // "HH:MM"

  TimetableSlot({
    this.id,
    required this.courseId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  /// Creates a [TimetableSlot] instance from a database map.
  factory TimetableSlot.fromMap(Map<String, dynamic> map) {
    return TimetableSlot(
      id: map['id'] as int?,
      courseId: map['course_id'] as int,
      dayOfWeek: map['day_of_week'] as int,
      startTime: map['start_time'] as String,
      endTime: map['end_time'] as String,
    );
  }

  /// Converts the [TimetableSlot] instance into a map for database insertion.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'course_id': courseId,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
    };
  }
}
