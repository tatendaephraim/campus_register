class AttendanceRecord {
  final int? id; // For database auto-increment
  final String name; // User name
  final String type; // Check-In or Check-Out
  final DateTime timestamp;
  final String location; // Lat, Lon as string
  final double altitude;
  final int estimatedFloor;
  final String venueName; // Name of the class/venue
  final String? venueDescription; // Additional venue details
  final double latitude; // Separated lat for easier queries
  final double longitude; // Separated lon for easier queries

  AttendanceRecord({
    this.id,
    required this.name,
    required this.type,
    required this.timestamp,
    required this.location,
    required this.altitude,
    required this.estimatedFloor,
    required this.venueName,
    this.venueDescription,
    required this.latitude,
    required this.longitude,
  });

  // Convert to Map for SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'location': location,
      'altitude': altitude,
      'estimatedFloor': estimatedFloor,
      'venueName': venueName,
      'venueDescription': venueDescription,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  // Create from Map (SQLite query result)
  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      location: map['location'] as String,
      altitude: map['altitude'] as double,
      estimatedFloor: map['estimatedFloor'] as int,
      venueName: map['venueName'] as String,
      venueDescription: map['venueDescription'] as String?,
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
    );
  }

  // For Google Sheets sync
  Map<String, dynamic> toSyncData() {
    return {
      'Name': name,
      'Type': type,
      'Timestamp': timestamp.toIso8601String(),
      'Venue': venueName,
      'Description': venueDescription ?? '',
      'Location': location,
      'Latitude': latitude.toStringAsFixed(6),
      'Longitude': longitude.toStringAsFixed(6),
      'Altitude': '${altitude.toStringAsFixed(1)}m',
      'Floor': 'Floor $estimatedFloor',
    };
  }

  @override
  String toString() {
    return 'AttendanceRecord(id: $id, name: $name, type: $type, venue: $venueName, time: $timestamp, altitude: ${altitude.toStringAsFixed(1)}m, floor: $estimatedFloor)';
  }
}
