import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'course.dart';
import 'student.dart';
import 'attendance_repository.dart';
import 'check_in_repository.dart';
import 'teacher_report_view.dart';
import 'student_repository.dart';
import 'ui/design_tokens.dart';

class HistoricalReportScreen extends StatefulWidget {
  final Course course;
  const HistoricalReportScreen({super.key, required this.course});

  @override
  State<HistoricalReportScreen> createState() => _HistoricalReportScreenState();
}

class _HistoricalReportScreenState extends State<HistoricalReportScreen> with SingleTickerProviderStateMixin {
  final _studentRepo = StudentRepository();
  final _attendanceRepo = AttendanceRepository();
  final _checkInRepo = CheckInRepository();

  late Future<List<dynamic>> _initialDataFuture;
  List<TeacherReportView> _records = [];
  List<Student> _students = [];
  late TabController _tabController;

  // Filter state
  int? _selectedStudentId;
  DateTimeRange? _selectedDateRange;

  // Pagination state
  int _currentPage = 0;
  int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadData() {
    _initialDataFuture = _checkInRepo.backfillAbsentRecords(widget.course.id!).then((_) {
      return Future.wait([
        _attendanceRepo.getHistoricalReportForCourse(widget.course.id!),
        _studentRepo.getStudentsForCourse(widget.course.id!),
      ]);
    });
  }

  void _applyFilters() {
    setState(() {
      _currentPage = 0; // Reset pagination on filter change
      _initialDataFuture = _checkInRepo.backfillAbsentRecords(widget.course.id!).then((_) {
        return Future.wait([
          _attendanceRepo.getHistoricalReportForCourse(
            widget.course.id!,
            studentId: _selectedStudentId,
            startDate: _selectedDateRange?.start,
            endDate: _selectedDateRange?.end,
          ),
          Future.value(_students), // Retain the students list
        ]);
      });
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

  Future<void> _exportToCsv() async {
    if (_records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('There are no records to export.')),
      );
      return;
    }

    final List<List<dynamic>> rows = [];
    rows.add([
      'Student Name',
      'Date',
      'Day',
      'Scheduled Time',
      'Status',
      'Check-in Timestamp'
    ]);

    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all_rounded),
            onPressed: _clearFilters,
            tooltip: 'Clear Filters',
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: _exportToCsv,
            tooltip: 'Export to CSV',
          )
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
        child: FutureBuilder<List<dynamic>>(
          future: _initialDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            _records = snapshot.data![0] as List<TeacherReportView>;
            _students = snapshot.data![1] as List<Student>;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Filter and Date display Bar
                _buildFilterBar(theme, isDark),

                if (_records.isNotEmpty) ...[
                  // Premium Charts Section (Pie & Line Charts)
                  _buildChartsSection(theme, isDark),
                ],

                // Tab Bar
                Container(
                  color: isDark ? AppColors.slate800.withOpacity(0.4) : Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: theme.colorScheme.primary,
                    labelColor: theme.colorScheme.primary,
                    unselectedLabelColor: AppColors.textSecondary(isDark),
                    tabs: const [
                      Tab(icon: Icon(Icons.people_outline_rounded), text: 'Student roster'),
                      Tab(icon: Icon(Icons.list_alt_rounded), text: 'Attendance logs'),
                    ],
                  ),
                ),

                // Tab Contents
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRosterTab(theme, isDark),
                      _buildLogsTab(theme, isDark),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.sm),
      child: Card(
        color: isDark ? AppColors.slate800.withOpacity(0.5) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        isExpanded: true,
                        value: _selectedStudentId,
                        hint: const Text('Filter by student'),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('All students'),
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
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    color: AppColors.border(isDark),
                    margin: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
                  ),
                  IconButton(
                    icon: Icon(Icons.calendar_month_rounded, color: theme.colorScheme.primary),
                    onPressed: _pickDateRange,
                    tooltip: 'Select date range',
                  ),
                ],
              ),
              if (_selectedDateRange != null) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Range: ${DateFormat.yMMMd().format(_selectedDateRange!.start)} – ${DateFormat.yMMMd().format(_selectedDateRange!.end)}',
                        style: AppType.data(context, fontSize: 12, weight: FontWeight.w600, color: AppColors.textPrimary(isDark)),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDateRange = null;
                            _applyFilters();
                          });
                        },
                        child: Text(
                          'Clear range',
                          style: AppType.body(context, color: AppColors.dangerDark, fontSize: 11, weight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartsSection(ThemeData theme, bool isDark) {
    // Math to compute records stats
    final present = _records.where((r) => r.status.toUpperCase() == 'PRESENT').length;
    final late = _records.where((r) => r.status.toUpperCase() == 'LATE').length;
    final absent = _records.where((r) => r.status.toUpperCase() == 'ABSENT').length;
    final total = present + late + absent;

    final double presentPct = total > 0 ? present / total : 0;
    final double latePct = total > 0 ? late / total : 0;
    final double absentPct = total > 0 ? absent / total : 0;

    // Grouping by Date for Line Chart
    final Map<String, List<TeacherReportView>> groupedByDate = {};
    for (var r in _records) {
      final dateStr = DateFormat('MM/dd').format(r.timestamp);
      groupedByDate.putIfAbsent(dateStr, () => []).add(r);
    }
    final sortedDates = groupedByDate.keys.toList()..sort();
    final List<double> rateHistory = [];
    final List<String> rateLabels = [];

    // Calculate rates for the last 5 active classroom dates
    final activeDates = sortedDates.length > 5 ? sortedDates.sublist(sortedDates.length - 5) : sortedDates;
    for (var date in activeDates) {
      final dayRecords = groupedByDate[date]!;
      final dayPresent = dayRecords.where((r) => r.status.toUpperCase() == 'PRESENT' || r.status.toUpperCase() == 'LATE').length;
      final dayRate = dayRecords.isNotEmpty ? dayPresent / dayRecords.length : 0.0;
      rateHistory.add(dayRate);
      rateLabels.add(date);
    }

    final surfaceColor = isDark ? AppColors.slate800 : Colors.white;

    return Container(
      height: 180,
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.sm),
      child: Row(
        children: [
          // Pie Chart Card (45% width)
          Expanded(
            flex: 45,
            child: Card(
              color: surfaceColor,
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.md),
                child: Column(
                  children: [
                    Expanded(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: CustomPieChartPainter(
                          data: {
                            'Present': present.toDouble(),
                            'Late': late.toDouble(),
                            'Absent': absent.toDouble(),
                          },
                          colors: {
                            'Present': AppColors.success,
                            'Late': AppColors.warning,
                            'Absent': AppColors.danger,
                          },
                          surfaceColor: surfaceColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildLegendDot(AppColors.success, 'P: ${(presentPct * 100).toStringAsFixed(0)}%'),
                        _buildLegendDot(AppColors.warning, 'L: ${(latePct * 100).toStringAsFixed(0)}%'),
                        _buildLegendDot(AppColors.danger, 'A: ${(absentPct * 100).toStringAsFixed(0)}%'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: AppSpace.sm),

          // Line Chart Card (55% width)
          Expanded(
            flex: 55,
            child: Card(
              color: surfaceColor,
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ATTENDANCE RATE TREND',
                      style: AppType.body(context, weight: FontWeight.w700, fontSize: 9.5, color: AppColors.textSecondary(isDark), letterSpacing: 0.4),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: CustomLineChartPainter(
                          values: rateHistory,
                          labels: rateLabels,
                          lineColor: theme.colorScheme.primary,
                          gridColor: isDark ? Colors.white.withOpacity(0.08) : AppColors.slate200,
                          textColor: isDark ? Colors.grey[500]! : AppColors.slate500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: AppType.body(context, fontSize: 9, weight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildRosterTab(ThemeData theme, bool isDark) {
    if (_students.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xxxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/lottie/form_reg.json',
                height: 160,
                width: 160,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: AppSpace.md),
              Text(
                'No students registered yet',
                style: AppType.display(context, fontSize: 16, weight: FontWeight.w600, color: AppColors.textPrimary(isDark)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.md),
      itemCount: _students.length,
      itemBuilder: (context, index) {
        final student = _students[index];
        final name = student.name;

        // Extract student records
        final studentRecords = _records
            .where((r) => r.studentName.trim().toLowerCase() == name.trim().toLowerCase())
            .toList();

        final sPresent = studentRecords.where((r) => r.status.toUpperCase() == 'PRESENT').length;
        final sLate = studentRecords.where((r) => r.status.toUpperCase() == 'LATE').length;
        final sAbsent = studentRecords.where((r) => r.status.toUpperCase() == 'ABSENT').length;
        final sTotal = sPresent + sLate + sAbsent;
        final double rate = sTotal > 0 ? (sPresent + sLate) / sTotal : 0.0;

        Color rateColor = AppColors.danger;
        if (rate >= 0.85) {
          rateColor = AppColors.success;
        } else if (rate >= 0.60) {
          rateColor = AppColors.warning;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: AppSpace.sm + 2),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'S',
                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              name,
              style: AppType.display(context, fontSize: 15.5, weight: FontWeight.w600, color: AppColors.textPrimary(isDark)),
            ),
            subtitle: Text(
              'Code: ${student.deviceAppId.length > 8 ? student.deviceAppId.substring(0, 8) : student.deviceAppId}…',
              style: AppType.data(context, fontSize: 12, color: AppColors.textSecondary(isDark)),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: rateColor.withOpacity(0.1),
                borderRadius: AppRadius.smR,
                border: Border.all(color: rateColor.withOpacity(0.2)),
              ),
              child: Text(
                '${(rate * 100).toStringAsFixed(0)}%',
                style: AppType.data(context, color: rateColor, weight: FontWeight.w600, fontSize: 13),
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildRosterStatChip('Classes logged', sTotal.toString(), AppColors.sky),
                    _buildRosterStatChip('Present', sPresent.toString(), AppColors.success),
                    _buildRosterStatChip('Late', sLate.toString(), AppColors.warning),
                    _buildRosterStatChip('Absent', sAbsent.toString(), AppColors.danger),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRosterStatChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: AppType.data(context, fontSize: 16, weight: FontWeight.w700, color: color),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppType.body(context, fontSize: 10, color: AppColors.slate500)),
      ],
    );
  }

  Widget _buildLogsTab(ThemeData theme, bool isDark) {
    if (_records.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xxxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/lottie/form_reg.json',
                height: 160,
                width: 160,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.bar_chart_outlined,
                  size: 64,
                  color: AppColors.slate400,
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              Text(
                'No attendance records found',
                style: AppType.display(context, fontSize: 16, weight: FontWeight.w600, color: AppColors.textPrimary(isDark)),
              ),
            ],
          ),
        ),
      );
    }

    // Paginated list calculation
    final totalRecords = _records.length;
    final totalPages = (totalRecords / _pageSize).ceil();

    if (_currentPage >= totalPages) {
      _currentPage = 0;
    }

    final startIndex = _currentPage * _pageSize;
    final endIndex = math.min(startIndex + _pageSize, totalRecords);
    final pageRecords = _records.sublist(startIndex, endIndex);

    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Column(
      children: [
        // Roster Logs List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.sm),
            itemCount: pageRecords.length,
            itemBuilder: (context, index) {
              final record = pageRecords[index];
              final day = days[record.dayOfWeek - 1];

              return Card(
                margin: const EdgeInsets.only(bottom: AppSpace.sm),
                child: ListTile(
                  title: Text(
                    record.studentName,
                    style: AppType.display(context, fontSize: 14.5, weight: FontWeight.w600, color: AppColors.textPrimary(isDark)),
                  ),
                  subtitle: Text(
                    '${DateFormat.yMMMd().format(record.timestamp)} ($day ${record.startTime})',
                    style: AppType.data(context, fontSize: 12, color: AppColors.textSecondary(isDark)),
                  ),
                  trailing: Chip(
                    label: Text(
                      record.status,
                      style: AppType.body(context, color: Colors.white, weight: FontWeight.w700, fontSize: 11),
                    ),
                    backgroundColor: _getStatusColor(record.status),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.smR),
                    side: BorderSide.none,
                  ),
                ),
              );
            },
          ),
        ),

        // Pagination controls footer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.sm + 2),
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate900 : Colors.white,
            border: Border(
              top: BorderSide(color: AppColors.border(isDark), width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Page size configuration
              Row(
                children: [
                  Text('Size:', style: AppType.body(context, fontSize: 11, weight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  DropdownButton<int>(
                    value: _pageSize,
                    items: const [10, 20, 50].map((size) {
                      return DropdownMenuItem<int>(
                        value: size,
                        child: Text(size.toString(), style: const TextStyle(fontSize: 12)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _pageSize = val;
                          _currentPage = 0;
                        });
                      }
                    },
                    icon: const Icon(Icons.arrow_drop_down_rounded, size: 16),
                    underline: const SizedBox(),
                  ),
                ],
              ),

              // Page info display
              Text(
                'Showing ${startIndex + 1} – $endIndex of $totalRecords',
                style: AppType.data(context, fontSize: 11, weight: FontWeight.w600, color: AppColors.textSecondary(isDark)),
              ),

              // Nav controls
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 20),
                    onPressed: _currentPage > 0
                        ? () {
                            setState(() {
                              _currentPage--;
                            });
                          }
                        : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Text(
                    '${_currentPage + 1} / $totalPages',
                    style: AppType.data(context, fontSize: 12, weight: FontWeight.w700, color: AppColors.textPrimary(isDark)),
                  ),
                  const SizedBox(width: AppSpace.md),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 20),
                    onPressed: _currentPage < totalPages - 1
                        ? () {
                            setState(() {
                              _currentPage++;
                            });
                          }
                        : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
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
      default:
        return Colors.grey;
    }
  }
}

class CustomPieChartPainter extends CustomPainter {
  final Map<String, double> data;
  final Map<String, Color> colors;
  final Color surfaceColor;

  CustomPieChartPainter({
    required this.data,
    required this.colors,
    required this.surfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double total = data.values.fold(0, (sum, val) => sum + val);
    if (total == 0) {
      // Draw empty placeholder circle
      final paint = Paint()
        ..color = Colors.grey.withOpacity(0.2)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2, paint);
      return;
    }

    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    double startAngle = -math.pi / 2;

    data.forEach((key, val) {
      if (val == 0) return;
      final sweepAngle = (val / total) * 2 * math.pi;
      paint.color = colors[key] ?? Colors.grey;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      final borderPaint = Paint()
        ..color = surfaceColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        borderPaint,
      );

      startAngle += sweepAngle;
    });

    final innerPaint = Paint()
      ..color = surfaceColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.55, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CustomLineChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;

  CustomLineChartPainter({
    required this.values,
    required this.labels,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double paddingLeft = 32.0;
    final double paddingRight = 12.0;
    final double paddingTop = 12.0;
    final double paddingBottom = 20.0;

    final double chartWidth = size.width - paddingLeft - paddingRight;
    final double chartHeight = size.height - paddingTop - paddingBottom;

    final paintGrid = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Draw horizontal grid lines (0%, 25%, 50%, 75%, 100%)
    for (int i = 0; i <= 4; i++) {
      final double y = paddingTop + (chartHeight * (1.0 - (i / 4.0)));
      canvas.drawLine(
        Offset(paddingLeft, y),
        Offset(size.width - paddingRight, y),
        paintGrid,
      );

      // Draw grid labels
      final tp = TextPainter(
        text: TextSpan(
          text: '${i * 25}%',
          style: TextStyle(color: textColor, fontSize: 8, fontWeight: FontWeight.bold),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(paddingLeft - tp.width - 6, y - tp.height / 2));
    }

    if (values.isEmpty) return;

    final paintLine = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintPoint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    final paintArea = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [lineColor.withOpacity(0.25), lineColor.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(paddingLeft, paddingTop, chartWidth, chartHeight));

    final double stepX = values.length > 1 ? chartWidth / (values.length - 1) : chartWidth;
    final points = <Offset>[];

    for (int i = 0; i < values.length; i++) {
      final double x = paddingLeft + (i * stepX);
      final double y = paddingTop + (chartHeight * (1.0 - values[i]));
      points.add(Offset(x, y));

      // Draw date labels
      if (i < labels.length) {
        final tp = TextPainter(
          text: TextSpan(
            text: labels[i],
            style: TextStyle(color: textColor, fontSize: 8, fontWeight: FontWeight.bold),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, size.height - paddingBottom + 4));
      }
    }

    // Draw Line and Area
    if (points.isNotEmpty) {
      final path = Path();
      path.moveTo(points[0].dx, points[0].dy);
      for (int i = 1; i < points.length; i++) {
        final p0 = points[i - 1];
        final p1 = points[i];
        final controlX1 = p0.dx + (p1.dx - p0.dx) / 2;
        final controlY1 = p0.dy;
        final controlX2 = p0.dx + (p1.dx - p0.dx) / 2;
        final controlY2 = p1.dy;
        path.cubicTo(controlX1, controlY1, controlX2, controlY2, p1.dx, p1.dy);
      }
      canvas.drawPath(path, paintLine);

      // Draw filled area under line
      final areaPath = Path.from(path);
      areaPath.lineTo(points.last.dx, paddingTop + chartHeight);
      areaPath.lineTo(points.first.dx, paddingTop + chartHeight);
      areaPath.close();
      canvas.drawPath(areaPath, paintArea);

      // Draw point markers
      for (final p in points) {
        canvas.drawCircle(p, 4.0, paintPoint);
        final whiteRing = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawCircle(p, 4.0, whiteRing);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
