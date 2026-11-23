/// Stores global timetable constraints set by organization admins.
class TimetableConstraints {
  final int? id;
  final int organizationId;
  final String startTime; // E.g. '08:00'
  final String endTime;   // E.g. '17:00'
  final String? breakStart; // E.g. '10:30'
  final int? breakDurationMins;
  final String? lunchStart; // E.g. '13:00'
  final int? lunchDurationMins;
  final String? assemblyStart; // E.g. '08:00'
  final int? assemblyDurationMins;

  TimetableConstraints({
    this.id,
    required this.organizationId,
    required this.startTime,
    required this.endTime,
    this.breakStart,
    this.breakDurationMins,
    this.lunchStart,
    this.lunchDurationMins,
    this.assemblyStart,
    this.assemblyDurationMins,
  });

  factory TimetableConstraints.fromMap(Map<String, dynamic> map) {
    return TimetableConstraints(
      id: map['id'] as int?,
      organizationId: map['organization_id'] as int,
      startTime: map['start_time'] as String,
      endTime: map['end_time'] as String,
      breakStart: map['break_start'] as String?,
      breakDurationMins: map['break_duration_mins'] as int?,
      lunchStart: map['lunch_start'] as String?,
      lunchDurationMins: map['lunch_duration_mins'] as int?,
      assemblyStart: map['assembly_start'] as String?,
      assemblyDurationMins: map['assembly_duration_mins'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'start_time': startTime,
      'end_time': endTime,
      'break_start': breakStart,
      'break_duration_mins': breakDurationMins,
      'lunch_start': lunchStart,
      'lunch_duration_mins': lunchDurationMins,
      'assembly_start': assemblyStart,
      'assembly_duration_mins': assemblyDurationMins,
    };
  }
}
