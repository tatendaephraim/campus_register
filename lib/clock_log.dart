/// Represents a check-in / check-out log for employees or teachers in offices or venues.
class ClockLog {
  final int? id;
  final int? teacherId; // Employee/Teacher link
  final int? studentId; // Employee (Business mode) link
  final String type; // 'office', 'venue'
  final int? venueId;
  final String clockIn; // ISO String timestamp
  final String? clockOut; // ISO String timestamp (null if active)
  final String? earlyLeaveReason;
  final int earlyLeaveApproved; // 0 (pending/no) or 1 (approved)

  ClockLog({
    this.id,
    this.teacherId,
    this.studentId,
    required this.type,
    this.venueId,
    required this.clockIn,
    this.clockOut,
    this.earlyLeaveReason,
    this.earlyLeaveApproved = 0,
  });

  factory ClockLog.fromMap(Map<String, dynamic> map) {
    return ClockLog(
      id: map['id'] as int?,
      teacherId: map['teacher_id'] as int?,
      studentId: map['student_id'] as int?,
      type: map['type'] as String,
      venueId: map['venue_id'] as int?,
      clockIn: map['clock_in'] as String,
      clockOut: map['clock_out'] as String?,
      earlyLeaveReason: map['early_leave_reason'] as String?,
      earlyLeaveApproved: map['early_leave_approved'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teacher_id': teacherId,
      'student_id': studentId,
      'type': type,
      'venue_id': venueId,
      'clock_in': clockIn,
      'clock_out': clockOut,
      'early_leave_reason': earlyLeaveReason,
      'early_leave_approved': earlyLeaveApproved,
    };
  }
}
