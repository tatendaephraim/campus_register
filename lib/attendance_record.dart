/// Represents a single attendance record for a student in a specific class session.
class AttendanceRecord {
  final int? id;
  final int studentId;
  final int timetableSlotId;
  final String type; // e.g., "CHECK-IN", "CHECK-OUT"
  final DateTime timestamp;
  final String status; // e.g., "PRESENT", "ABSENT", "LATE"
  final String location; // "Lat, Lon"
  final double altitude;
  final double latitude;
  final double longitude;
  final DateTime? checkedOutAt;

  AttendanceRecord({
    this.id,
    required this.studentId,
    required this.timetableSlotId,
    required this.type,
    required this.timestamp,
    required this.status,
    required this.location,
    required this.altitude,
    required this.latitude,
    required this.longitude,
    this.checkedOutAt,
  });

  /// Creates an [AttendanceRecord] instance from a database map.
  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'] as int?,
      studentId: map['student_id'] as int,
      timetableSlotId: map['timetable_slot_id'] as int,
      type: map['type'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      status: map['status'] as String,
      location: map['location'] as String,
      altitude: (map['altitude'] as num).toDouble(),
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      checkedOutAt: map['checked_out_at'] != null ? DateTime.parse(map['checked_out_at'] as String) : null,
    );
  }

  /// Converts the [AttendanceRecord] instance into a map for database insertion.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'timetable_slot_id': timetableSlotId,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
      'location': location,
      'altitude': altitude,
      'latitude': latitude,
      'longitude': longitude,
      'checked_out_at': checkedOutAt?.toIso8601String(),
    };
  }
}
