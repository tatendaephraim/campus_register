import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'course.dart';
import 'student.dart';
import 'attendance_repository.dart';
import 'teacher_report_view.dart';
import 'student_repository.dart';

class HistoricalReportScreen extends StatefulWidget {
  final Course course;
  const HistoricalReportScreen({super.key, required this.course});

  @override
  State<HistoricalReportScreen> createState() => _HistoricalReportScreenState();
}

class _HistoricalReportScreenState extends State<HistoricalReportScreen> {
  final _studentRepo = StudentRepository();
  final _attendanceRepo = AttendanceRepository();

  late Future<List<dynamic>> _initialDataFuture;
  List<TeacherReportView> _records = [];
  List<Student> _students = [];

  // Filter state
  int? _selectedStudentId;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    // Fetch both reports and students in a single future
    _initialDataFuture = Future.wait([
      _attendanceRepo.getHistoricalReportForCourse(widget.course.id!),
      _studentRepo.getStudentsForCourse(widget.course.id!),
    ]);
  }

  void _applyFilters() {
    setState(() {
      // Re-fetch the data from the database with the applied filters
      _initialDataFuture = Future.wait([
        _attendanceRepo.getHistoricalReportForCourse(
          widget.course.id!,
          studentId: _selectedStudentId,
          startDate: _selectedDateRange?.start,
          endDate: _selectedDateRange?.end,
        ),
        // We don't need to re-fetch students, but Future.wait needs a list.
        // We could optimize this, but for simplicity, we'll keep it.
        Future.value(_students),
      ]);
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedStudentId = null;
      _selectedDateRange = null;
      _applyFilters();
    });
  }

  Future<void> _pickDateRange() async {
    final newDateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedDateRange,
    );

    if (newDateRange != null) {
      setState(() {
        _selectedDateRange = newDateRange;
        _applyFilters();
      });
    }
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: DropdownButton<int?>(
              isExpanded: true,
              value: _selectedStudentId,
              hint: const Text('All Students'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('All Students'),
                ),
                ..._students.map((student) => DropdownMenuItem<int?>(
                      value: student.id,
                      child: Text(student.name),
                    )),
              ],
              onChanged: (value) {
                setState(() => _selectedStudentId = value);
                _applyFilters();
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _pickDateRange,
            tooltip: 'Select Date Range',
          ),
        ],
      ),
    );
  }

  Future<void> _exportToCsv() async {
    if (_records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('There are no records to export.')),
      );
      return;
    }

    final List<List<dynamic>> rows = [];
    // Add header row
    rows.add([
      'Student Name',
      'Date',
      'Day',
      'Scheduled Time',
      'Status',
      'Check-in Timestamp'
    ]);

    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    // Add data rows
    for (final record in _records) {
      rows.add([
        record.studentName,
        DateFormat.yMMMd().format(record.timestamp),
        days[record.dayOfWeek - 1],
        '${record.startTime} - ${record.endTime}',
        record.status,
        record.timestamp.toIso8601String(),
      ]);
    }

    final String csv = const ListToCsvConverter().convert(rows);

    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/${widget.course.name.replaceAll(' ', '_')}_Report.csv';
    final file = File(path);
    await file.writeAsString(csv);

    await Share.shareXFiles([XFile(path)], text: 'Attendance Report for ${widget.course.name}');
  }

  Widget _buildSummaryView() {
    if (_records.isEmpty) {
      return const SizedBox.shrink(); // Don't show summary if there are no records
    }

    final presentCount =
        _records.where((r) => r.status.toUpperCase() == 'PRESENT').length;
    final lateCount =
        _records.where((r) => r.status.toUpperCase() == 'LATE').length;
    final absentCount =
        _records.where((r) => r.status.toUpperCase() == 'ABSENT').length;
    final total = presentCount + lateCount + absentCount;
    final attendanceRate =
        total > 0 ? (presentCount + lateCount) / total * 100 : 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatColumn('Present', presentCount.toString(), Colors.green),
            _buildStatColumn('Late', lateCount.toString(), Colors.orange),
            _buildStatColumn('Absent', absentCount.toString(), Colors.red),
            _buildStatColumn(
                'Attendance', '${attendanceRate.toStringAsFixed(0)}%', Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String title, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(title, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearFilters,
            tooltip: 'Clear Filters',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _exportToCsv,
            tooltip: 'Export to CSV',
          )
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _initialDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          _records = snapshot.data![0];
          _students = snapshot.data![1];

          return Column(
            children: [
              _buildSummaryView(),
              _buildFilterBar(),
              if (_selectedDateRange != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Showing: ${DateFormat.yMMMd().format(_selectedDateRange!.start)} - ${DateFormat.yMMMd().format(_selectedDateRange!.end)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const Divider(),
              Expanded(child: _buildRecordList()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRecordList() {
    if (_records.isEmpty) {
            return const Center(child: Text('No attendance records found.'));
          }

          return ListView.builder(
            itemCount: _records.length,
            itemBuilder: (context, index) {
              final record = _records[index];
              final day = [
                'Mon',
                'Tue',
                'Wed',
                'Thu',
                'Fri',
                'Sat',
                'Sun'
              ][record.dayOfWeek - 1];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(record.studentName),
                  subtitle: Text(
                      '${DateFormat.yMMMd().format(record.timestamp)} ($day ${record.startTime})'),
                  trailing: Chip(
                    label: Text(record.status),
                    backgroundColor: _getStatusColor(record.status),
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
                ),
              );
            },
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
      default:
        return Colors.grey;
    }
  }
}
