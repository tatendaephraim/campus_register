import 'package:flutter/material.dart';

import 'attendance_record.dart';
import 'course.dart';
import 'student.dart';
import 'timetable.dart';
import 'check_in_repository.dart';
import 'student_repository.dart';
import 'ui/design_tokens.dart';

class LiveAttendanceScreen extends StatefulWidget {
  final Course course;
  final TimetableSlot slot;

  const LiveAttendanceScreen(
      {super.key, required this.course, required this.slot});

  @override
  State<LiveAttendanceScreen> createState() => _LiveAttendanceScreenState();
}

class _LiveAttendanceScreenState extends State<LiveAttendanceScreen> {
  final _studentRepo = StudentRepository();
  final _checkInRepo = CheckInRepository();
  Map<int, String> _attendanceStatus = {}; // studentId -> status
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAttendanceStatus();
  }

  Future<void> _fetchAttendanceStatus() async {
    setState(() => _isLoading = true);
    final students = await _studentRepo.getStudentsForCourse(widget.course.id!);
    final records = await _checkInRepo.getRecordsForSlotOnDate(
        widget.slot.id!, DateTime.now());

    final newStatus = <int, String>{};
    for (var student in students) {
      newStatus[student.id!] = 'PENDING'; // Default status
    }
    for (var record in records) {
      newStatus[record.studentId] = record.status;
    }

    setState(() {
      _attendanceStatus = newStatus;
      _isLoading = false;
    });
  }

  Future<void> _markAbsentees() async {
    final now = DateTime.now();
    final absentStudentIds = _attendanceStatus.entries
        .where((entry) => entry.value == 'PENDING')
        .map((entry) => entry.key)
        .toList();

    if (absentStudentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pending students to mark as absent.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await _checkInRepo.batchCreateAbsentRecords(
        absentStudentIds, widget.slot.id!, now);

    // Refresh the view
    _fetchAttendanceStatus();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${absentStudentIds.length} students marked as ABSENT.'),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showEditStatusDialog(
      int studentId, String currentStatus) async {
    final newStatus = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Change attendance status', style: AppType.display(context, fontSize: 17, weight: FontWeight.w600)),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xlR),
        children: [
          _buildStatusOption(context, 'PRESENT', currentStatus),
          _buildStatusOption(context, 'LATE', currentStatus),
          _buildStatusOption(context, 'ABSENT', currentStatus),
        ],
      ),
    );

    if (newStatus != null && newStatus != currentStatus) {
      await _checkInRepo.upsertAttendanceStatus(
          studentId, widget.slot.id!, newStatus);
      _fetchAttendanceStatus(); // Refresh the list after updating
    }
  }

  Widget _buildStatusOption(
      BuildContext context, String status, String currentStatus) {
    final isSelected = status == currentStatus;
    final color = _getStatusColor(status);
    return SimpleDialogOption(
      onPressed: () => Navigator.pop(context, status),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: isSelected ? color : Colors.transparent,
              size: 20,
            ),
            const SizedBox(width: AppSpace.sm + 2),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpace.sm),
            Text(
              status,
              style: AppType.body(
                context,
                weight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchAttendanceStatus,
            tooltip: 'Refresh status',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [AppColors.slate900, AppColors.slate800]
                : [AppColors.slate50, const Color(0xFFEEF2F6)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.lg),
                itemCount: _attendanceStatus.length,
                itemBuilder: (context, index) {
                  final studentId = _attendanceStatus.keys.elementAt(index);
                  final status = _attendanceStatus[studentId]!;
                  // This is not efficient, but works for this example.
                  // A better approach would be to fetch students once.
                  return FutureBuilder<Student?>(
                    future: _studentRepo.getStudentById(studentId),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();
                      final student = snapshot.data!;
                      final color = _getStatusColor(status);
                      return Card(
                        margin: const EdgeInsets.only(bottom: AppSpace.sm + 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.lgR,
                          side: BorderSide(color: AppColors.border(isDark), width: 1),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.xs),
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
                            child: Icon(Icons.person_rounded, color: theme.colorScheme.primary),
                          ),
                          title: Text(
                            student.name,
                            style: AppType.display(context, fontSize: 15, weight: FontWeight.w600, color: AppColors.textPrimary(isDark)),
                          ),
                          trailing: Chip(
                            label: Text(status),
                            backgroundColor: color,
                            labelStyle: AppType.body(context, color: Colors.white, weight: FontWeight.w700, fontSize: 12),
                            shape: RoundedRectangleBorder(borderRadius: AppRadius.smR),
                            side: BorderSide.none,
                          ),
                          onTap: () => _showEditStatusDialog(
                            student.id!,
                            status,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _markAbsentees,
        icon: const Icon(Icons.person_off_outlined),
        label: const Text('Mark remaining as absent'),
        backgroundColor: AppColors.dangerDark,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PRESENT':
        return AppColors.success;
      case 'LATE':
        return AppColors.warning;
      case 'ABSENT':
        return AppColors.danger;
      default: // PENDING
        return AppColors.slate400;
    }
  }
}

extension on StudentRepository {
  // Helper to get a single student by ID for the UI builder.
  Future<Student?> getStudentById(int id) async {
    final db = await dbHelper.database;
    final maps = await db.query('students', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return Student.fromMap(maps.first);
    }
    return null;
  }
}
