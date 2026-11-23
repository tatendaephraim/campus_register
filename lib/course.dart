/// Represents a course or class taught by a teacher.
class Course {
  final int? id;
  final int teacherId;
  final String name;
  final String? schoolName;
  final DateTime startDate;
  final DateTime endDate;
  final int? venueId;

  Course({
    this.id,
    required this.teacherId,
    required this.name,
    this.schoolName,
    required this.startDate,
    required this.endDate,
    this.venueId,
  });

  /// Creates a [Course] instance from a database map.
  factory Course.fromMap(Map<String, dynamic> map) {
    return Course(
      id: map['id'] as int?,
      teacherId: map['teacher_id'] as int,
      name: map['name'] as String,
      schoolName: map['school_name'] as String?,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      venueId: map['venue_id'] as int?,
    );
  }

  /// Converts the [Course] instance into a map for database insertion.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teacher_id': teacherId,
      'name': name,
      'school_name': schoolName,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'venue_id': venueId,
    };
  }
}
