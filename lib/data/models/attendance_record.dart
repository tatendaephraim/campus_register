import 'package:flutter/foundation.dart';

@immutable
class AttendanceRecord {
  final String name;
  final String type; // "IN" or "OUT"
  final String timestamp;
  final String location; // "lat,lon"

  AttendanceRecord({
    required this.name,
    required this.type,
    required this.timestamp,
    required this.location,
  });

  factory AttendanceRecord.create({
    required String name,
    required String type,
    required double lat,
    required double lon,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    return AttendanceRecord(
      name: name,
      type: type,
      timestamp: timestamp,
      location: '$lat,$lon',
    );
  }
}