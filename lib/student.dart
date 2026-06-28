/// Represents a student enrolled in a course.
class Student {
  final int? id;
  final int? courseId; // Nullable now, as students belong to an organization first
  final int? organizationId;
  final String name;
  final String? email;
  final String deviceAppId;
  final int isApproved; // 0 or 1

  Student({
    this.id,
    this.courseId,
    this.organizationId,
    required this.name,
    this.email,
    required this.deviceAppId,
    this.isApproved = 0,
  });

  /// Creates a [Student] instance from a database map.
  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'] as int?,
      courseId: map['course_id'] as int?,
      organizationId: map['organization_id'] as int?,
      name: map['name'] as String,
      email: map['email'] as String?,
      deviceAppId: map['device_app_id'] as String? ?? '',
      isApproved: map['is_approved'] as int? ?? 0,
    );
  }

  /// Converts the [Student] instance into a map for database insertion.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'name': name,
      'email': email,
      'device_app_id': deviceAppId,
      'is_approved': isApproved,
    };
  }
}
