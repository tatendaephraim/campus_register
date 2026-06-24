/// Represents a student enrolled in a course.
class Student {
  final int? id;
  final int courseId;
  final String name;
  final String deviceAppId;

  Student({
    this.id,
    required this.courseId,
    required this.name,
    required this.deviceAppId,
  });

  /// Creates a [Student] instance from a database map.
  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'] as int?,
      courseId: map['course_id'] as int,
      name: map['name'] as String,
      deviceAppId: map['device_app_id'] as String,
    );
  }

  /// Converts the [Student] instance into a map for database insertion.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'course_id': courseId,
      'name': name,
      'device_app_id': deviceAppId,
    };
  }
}
