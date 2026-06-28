/// Represents a waiver recorded for an absence, such as a sick leave with medical proof.
class AttendanceWaiver {
  final int? id;
  final int? studentId;
  final int? teacherId;
  final String date; // 'YYYY-MM-DD'
  final String reason;
  final int hasMedicalProof; // 0 or 1
  final int? approvedById; // Teacher or Admin ID

  AttendanceWaiver({
    this.id,
    this.studentId,
    this.teacherId,
    required this.date,
    required this.reason,
    this.hasMedicalProof = 0,
    this.approvedById,
  });

  factory AttendanceWaiver.fromMap(Map<String, dynamic> map) {
    return AttendanceWaiver(
      id: map['id'] as int?,
      studentId: map['student_id'] as int?,
      teacherId: map['teacher_id'] as int?,
      date: map['date'] as String,
      reason: map['reason'] as String,
      hasMedicalProof: map['has_medical_proof'] as int? ?? 0,
      approvedById: map['approved_by_id'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'teacher_id': teacherId,
      'date': date,
      'reason': reason,
      'has_medical_proof': hasMedicalProof,
      'approved_by_id': approvedById,
    };
  }
}
