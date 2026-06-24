import 'package:flutter/material.dart';

import 'attendance_record.dart';
import 'course.dart';
import 'student.dart';
import 'timetable.dart';
import 'check_in_repository.dart';
import 'student_repository.dart';

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
        const SnackBar(content: Text('No pending students to mark as absent.')),
      );
      return;
    }

    await _checkInRepo.batchCreateAbsentRecords(
        absentStudentIds, widget.slot.id!, now);

    // Refresh the view
    _fetchAttendanceStatus();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text('${absentStudentIds.length} students marked as ABSENT.'),
          backgroundColor: Colors.red),
    );
  }

  Future<void> _showEditStatusDialog(
      int studentId, String currentStatus) async {
    final newStatus = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Change Attendance Status'),
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
    return SimpleDialogOption(
      onPressed: () => Navigator.pop(context, status),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: status == currentStatus ? Colors.blue : Colors.transparent,
          ),
          const SizedBox(width: 8),
          Text(status,
              style: TextStyle(
                  fontWeight: status == currentStatus
                      ? FontWeight.bold
                      : FontWeight.normal)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAttendanceStatus,
            tooltip: 'Refresh Status',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _attendanceStatus.length,
              itemBuilder: (context, index) {
                final studentId = _attendanceStatus.keys.elementAt(index);
                final status = _attendanceStatus[studentId]!;
                // This is not efficient, but works for this example.
                // A better approach would be to fetch students once.
                return FutureBuilder<Student?>(
                  future: _studentRepo.getStudentById(studentId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const ListTile();
                    final student = snapshot.data!;
                    return ListTile(
                      title: Text(student.name),
                      trailing: Chip(
                        label: Text(status),
                        backgroundColor: _getStatusColor(status),
                        labelStyle: const TextStyle(color: Colors.white),
                      ),
                      onTap: () => _showEditStatusDialog(
                        student.id!,
                        status,
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _markAbsentees,
        icon: const Icon(Icons.person_off_outlined),
        label: const Text('Mark Remaining as Absent'),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PRESENT':
        return Colors.green;
      case 'LATE':
        return Colors.orange;
      case 'ABSENT':
        return Colors.red;
      default: // PENDING
        return Colors.grey;
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
