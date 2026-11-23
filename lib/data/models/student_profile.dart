import 'dart:math';

class StudentProfile {
  const StudentProfile({
    required this.studentId,
    required this.name,
    required this.deviceId,
  });

  final String studentId;
  final String name;

  /// Random per-installation identifier. It is not derived from hardware, so it
  /// cannot be used to track the device across apps.
  final String deviceId;

  factory StudentProfile.enrol({
    required String studentId,
    required String name,
  }) {
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return StudentProfile(
      studentId: studentId.trim().toUpperCase(),
      name: name.trim(),
      deviceId: id,
    );
  }

  factory StudentProfile.fromJson(Map<String, dynamic> json) => StudentProfile(
    studentId: json['studentId'] as String,
    name: json['name'] as String,
    deviceId: json['deviceId'] as String,
  );

  Map<String, String> toJson() => {
    'studentId': studentId,
    'name': name,
    'deviceId': deviceId,
  };
}
