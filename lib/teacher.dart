/// Represents a teacher in the system.
class Teacher {
  final int? id;
  final int? organizationId;
  final String name;
  final String email;
  final String? googleSheetUrl;
  final String role; // 'admin', 'teacher', 'employee'
  final int isApproved; // 0 or 1
  final String? deviceAppId;
  final int? officeVenueId;

  Teacher({
    this.id,
    this.organizationId,
    required this.name,
    required this.email,
    this.googleSheetUrl,
    this.role = 'teacher',
    this.isApproved = 0,
    this.deviceAppId,
    this.officeVenueId,
  });

  /// Creates a [Teacher] instance from a database map.
  factory Teacher.fromMap(Map<String, dynamic> map) {
    return Teacher(
      id: map['id'] as int?,
      organizationId: map['organization_id'] as int?,
      name: map['name'] as String,
      email: map['email'] as String,
      googleSheetUrl: map['google_sheet_url'] as String?,
      role: map['role'] as String? ?? 'teacher',
      isApproved: map['is_approved'] as int? ?? 0,
      deviceAppId: map['device_app_id'] as String?,
      officeVenueId: map['office_venue_id'] as int?,
    );
  }

  /// Converts the [Teacher] instance into a map for database insertion.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'name': name,
      'email': email,
      'google_sheet_url': googleSheetUrl,
      'role': role,
      'is_approved': isApproved,
      'device_app_id': deviceAppId,
      'office_venue_id': officeVenueId,
    };
  }
}
