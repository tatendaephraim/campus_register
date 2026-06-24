/// Represents a teacher in the system.
class Teacher {
  final int? id;
  final String name;
  final String email;
  final String? googleSheetUrl;

  Teacher({
    this.id,
    required this.name,
    required this.email,
    this.googleSheetUrl,
  });

  /// Creates a [Teacher] instance from a database map.
  factory Teacher.fromMap(Map<String, dynamic> map) {
    return Teacher(
      id: map['id'] as int?,
      name: map['name'] as String,
      email: map['email'] as String,
      googleSheetUrl: map['google_sheet_url'] as String?,
    );
  }

  /// Converts the [Teacher] instance into a map for database insertion.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'google_sheet_url': googleSheetUrl,
    };
  }
}
