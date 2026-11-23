import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'teacher.dart';
import 'package:lottie/lottie.dart';
import 'student.dart';
import 'organization.dart';
import 'timetable_constraints.dart';
import 'teacher_repository.dart';
import 'student_repository.dart';
import 'historical_report_screen.dart';
import 'attendance_repository.dart';
import 'clock_log_repository.dart';
import 'database_helper.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'organization_repository.dart';
import 'timetable_constraints_repository.dart';
import 'timetable_day_override.dart';
import 'manage_venues_screen.dart';
import 'settings_screen.dart';
import 'about_screen.dart';
import 'role_selection_screen.dart';
import 'venue.dart';
import 'venue_repository.dart';
import 'ui/design_tokens.dart';

class AdminDashboardScreen extends StatefulWidget {
  final Teacher admin;

  const AdminDashboardScreen({super.key, required this.admin});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _teacherRepo = TeacherRepository();
  final _studentRepo = StudentRepository();
  final _orgRepo = OrganizationRepository();

  Organization? _organization;
  List<Teacher> _pendingTeachers = [];
  List<Student> _pendingStudents = [];
  List<Student> _approvedStudents = [];
  List<Teacher> _approvedEmployees = [];

  // Analytics State
  String _analyticsRole = 'students'; // 'students' or 'employees'
  String _analyticsPeriod = 'weekly'; // 'weekly', 'monthly', 'yearly', 'all'
  Map<String, int> _studentStats = {'PRESENT': 0, 'LATE': 0, 'ABSENT': 0};
  Map<String, double> _studentTrend = {};
  Map<String, int> _employeeStats = {'CLOCKED_IN': 0, 'CLOCKED_OUT': 0};
  Map<String, double> _employeeTrend = {};

  // Pagination states
  int _studentPage = 0;
  final int _studentPageSize = 10;
  int _employeePage = 0;
  final int _employeePageSize = 10;

  int _currentIndex = 0;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoadingData = true);
    try {
      final org = await _orgRepo.getOrganizationById(widget.admin.organizationId!);
      if (org == null) {
        return;
      }

      final pendingTeachersFuture = _teacherRepo.getPendingEmployees(org.id!);
      final pendingStudentsFuture = _studentRepo.getPendingStudents(org.id!);
      final approvedStudentsFuture = _studentRepo.getApprovedStudents(org.id!);
      final approvedEmployeesFuture = _teacherRepo.getApprovedEmployees(org.id!);
      final studentStatsFuture =
          AttendanceRepository().getOrganizationAttendanceStats(org.id!, period: _analyticsPeriod);
      final studentTrendFuture =
          AttendanceRepository().getOrganizationAttendanceTrend(org.id!, period: _analyticsPeriod);
      final employeeStatsFuture =
          ClockLogRepository().getOrganizationClockStats(org.id!, period: _analyticsPeriod);
      final employeeTrendFuture =
          ClockLogRepository().getOrganizationClockTrend(org.id!, period: _analyticsPeriod);

      final results = await Future.wait([
        pendingTeachersFuture,
        pendingStudentsFuture,
        approvedStudentsFuture,
        approvedEmployeesFuture,
        studentStatsFuture,
        studentTrendFuture,
        employeeStatsFuture,
        employeeTrendFuture,
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _organization = org;
        _pendingTeachers = results[0] as List<Teacher>;
        _pendingStudents = results[1] as List<Student>;
        _approvedStudents = results[2] as List<Student>;
        _approvedEmployees = results[3] as List<Teacher>;
        _studentStats = results[4] as Map<String, int>;
        _studentTrend = results[5] as Map<String, double>;
        _employeeStats = results[6] as Map<String, int>;
        _employeeTrend = results[7] as Map<String, double>;
      });
    } catch (e) {
      debugPrint('Error loading admin dashboard data: $e');
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }



  Future<void> _approveTeacher(Teacher teacher, String role) async {
    await _teacherRepo.approveEmployee(teacher.id!, role);
    await _loadAllData();
  }

  Future<void> _rejectTeacher(Teacher teacher) async {
    await _teacherRepo.rejectEmployee(teacher.id!);
    await _loadAllData();
  }

  Future<void> _approveStudent(Student student) async {
    await _studentRepo.approveStudent(student.id!);
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Student Approved'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${student.name} is now approved.'),
              const SizedBox(height: 12),
              const Text('Provide them this 6-digit Device Registration Code to log in:'),
              const SizedBox(height: 8),
              Container(
                width: double.maxFinite,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.slate200,
                  borderRadius: AppRadius.mdR,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        student.deviceAppId,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: student.deviceAppId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Registration code copied!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
    await _loadAllData();
  }

  Future<void> _rejectStudent(Student student) async {
    await _studentRepo.rejectStudent(student.id!);
    await _loadAllData();
  }

  void _handleSignOut() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/.logged_in_teacher_email');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'ADMIN PORTAL 🌤️';
    } else if (hour < 18) {
      greeting = 'ADMIN PORTAL ☕';
    } else {
      greeting = 'ADMIN PORTAL 🌙';
    }

    final formattedDate = DateFormat('EEEE, MMMM d').format(DateTime.now());

    final pages = [
      _buildOverviewTab(isDark),
      _buildApprovalsTab(isDark),
      _buildMembersTab(isDark),
      _buildAnalyticsTab(isDark),
    ];

    return Scaffold(
      drawer: _buildDrawer(context),
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
        child: _isLoadingData
            ? const Center(child: CircularProgressIndicator())
            : NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverAppBar(
                      expandedHeight: 180.0,
                      pinned: true,
                      backgroundColor: isDark ? AppColors.slate950 : theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      title: Text(
                        _organization?.name ?? 'Admin Portal',
                        style: AppType.display(
                          context,
                          fontSize: 18,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      flexibleSpace: FlexibleSpaceBar(
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            SvgPicture.asset(
                              'assets/images/banner.svg',
                              fit: BoxFit.cover,
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black.withValues(alpha: 0.35),
                                    Colors.black.withValues(alpha: 0.0),
                                    Colors.black.withValues(alpha: 0.6),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(AppSpace.xl, 80.0, AppSpace.xl, AppSpace.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    greeting,
                                    style: AppType.body(
                                      context,
                                      color: Colors.white.withValues(alpha: 0.85),
                                      weight: FontWeight.w700,
                                      fontSize: 10,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.admin.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppType.display(
                                      context,
                                      fontSize: 22,
                                      weight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    formattedDate,
                                    style: AppType.body(
                                      context,
                                      fontSize: 12,
                                      color: Colors.white.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ];
                },
                body: pages[_currentIndex],
              ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: isDark ? AppColors.slate900 : Colors.white,
          selectedItemColor: theme.colorScheme.primary,
          unselectedItemColor: AppColors.textSecondary(isDark),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.check_circle_outline_rounded),
              activeIcon: Icon(Icons.check_circle_rounded),
              label: 'Approvals',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline_rounded),
              activeIcon: Icon(Icons.people_rounded),
              label: 'Members',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_rounded),
              activeIcon: Icon(Icons.bar_chart_rounded),
              label: 'Analytics',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Drawer(
      backgroundColor: isDark ? AppColors.slate900 : AppColors.slate50,
      child: Column(
        children: [
          // Premium Header matching Teacher Dashboard
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(AppSpace.xl, 60.0, AppSpace.xl, AppSpace.xl),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [AppColors.slate900, AppColors.slate800]
                    : [Colors.white, const Color(0xFFF3F4F6)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border(
                bottom: BorderSide(color: AppColors.border(isDark), width: 1.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.15),
                        blurRadius: 15,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: SvgPicture.asset(
                    'assets/images/logo.svg',
                    width: 76,
                    height: 76,
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                Text(
                  'Campus Register',
                  style: AppType.display(
                    context,
                    fontSize: 20,
                    weight: FontWeight.w800,
                    color: AppColors.textPrimary(isDark),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.15), width: 1),
                  ),
                  child: Text(
                    'ADMIN PORTAL',
                    style: AppType.body(
                      context,
                      fontSize: 9,
                      weight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          _buildDrawerItem(
            context,
            icon: Icons.dashboard_rounded,
            title: 'Overview',
            theme: theme,
            isDark: isDark,
            isActive: true,
            onTap: () => Navigator.of(context).pop(),
          ),
          _buildDrawerItem(
            context,
            icon: Icons.meeting_room_rounded,
            title: 'Venues Manager',
            theme: theme,
            isDark: isDark,
            isActive: false,
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => ManageVenuesScreen(organizationId: widget.admin.organizationId)),
              );
            },
          ),
          _buildDrawerItem(
            context,
            icon: Icons.timer_outlined,
            title: 'Timetable Constraints',
            theme: theme,
            isDark: isDark,
            isActive: false,
            onTap: () {
              Navigator.of(context).pop();
              if (_organization != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => TimetableConstraintsScreen(organization: _organization!),
                  ),
                );
              }
            },
          ),
          _buildDrawerItem(
            context,
            icon: Icons.business_rounded,
            title: 'Organization Info',
            theme: theme,
            isDark: isDark,
            isActive: false,
            onTap: () async {
              Navigator.of(context).pop();
              if (_organization != null) {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => OrganizationInfoScreen(organization: _organization!),
                  ),
                );
                _loadAllData();
              }
            },
          ),
          const Spacer(),
          _buildDrawerItem(
            context,
            icon: Icons.settings_rounded,
            title: 'Settings',
            theme: theme,
            isDark: isDark,
            isActive: false,
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          _buildDrawerItem(
            context,
            icon: Icons.info_rounded,
            title: 'About',
            theme: theme,
            isDark: isDark,
            isActive: false,
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AboutScreen()),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl, vertical: AppSpace.sm),
            child: Divider(color: AppColors.border(isDark), height: 1),
          ),
          _buildDrawerItem(
            context,
            icon: Icons.logout_rounded,
            title: 'Sign out',
            theme: theme,
            isDark: isDark,
            isActive: false,
            onTap: _handleSignOut,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required ThemeData theme,
    required bool isDark,
    required bool isActive,
    double indent = 0.0,
    required VoidCallback onTap,
  }) {
    final activeColor = theme.colorScheme.primary;
    final inactiveColor = AppColors.textSecondary(isDark);

    return Padding(
      padding: EdgeInsets.only(left: indent + AppSpace.md, right: AppSpace.md, top: AppSpace.xs, bottom: AppSpace.xs),
      child: Material(
        color: isActive ? activeColor.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: AppRadius.mdR,
        child: ListTile(
          onTap: onTap,
          dense: true,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdR),
          leading: Icon(
            icon,
            color: isActive ? activeColor : inactiveColor,
            size: 20,
          ),
          title: Text(
            title,
            style: AppType.body(
              context,
              fontSize: 13,
              color: isActive ? activeColor : inactiveColor,
              weight: isActive ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
          trailing: isActive
              ? Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 10,
                  color: activeColor,
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildApprovalsTab(bool isDark) {
    if (_pendingTeachers.isEmpty && _pendingStudents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/lottie/register.json',
                height: 160,
                width: 160,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.done_all_rounded,
                  size: 64,
                  color: AppColors.slate400,
                ),
              ),
              const SizedBox(height: AppSpace.md),
              Text(
                'All caught up! No pending approvals.',
                style: AppType.display(
                  context,
                  fontSize: 15,
                  weight: FontWeight.w600,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpace.lg),
      children: [
        if (_pendingTeachers.isNotEmpty) ...[
          Text(
            'PENDING EMPLOYEES / TEACHERS',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary(isDark), fontSize: 12, letterSpacing: 1.0),
          ),
          const SizedBox(height: 8),
          ..._pendingTeachers.map((teacher) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.indigoDark.withValues(alpha: 0.1),
                        child: const Icon(Icons.person, color: AppColors.indigoDark),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(teacher.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 2),
                            Text(teacher.email, style: TextStyle(color: AppColors.textSecondary(isDark), fontSize: 13)),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
                            onPressed: () => _approveTeacher(teacher, 'teacher'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel_rounded, color: Colors.red),
                            onPressed: () => _rejectTeacher(teacher),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 24),
        ],
        if (_pendingStudents.isNotEmpty) ...[
          Text(
            'PENDING STUDENTS / CUSTOMERS',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary(isDark), fontSize: 12, letterSpacing: 1.0),
          ),
          const SizedBox(height: 8),
          ..._pendingStudents.map((student) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.sky.withValues(alpha: 0.1),
                        child: const Icon(Icons.school, color: AppColors.sky),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
                            onPressed: () => _approveStudent(student),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel_rounded, color: Colors.red),
                            onPressed: () => _rejectStudent(student),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ],
    );
  }



  Future<void> _exportAdminMetricsToCsv() async {
    final org = _organization;
    if (org == null) return;

    final db = await DatabaseHelper.instance.database;
    final List<List<dynamic>> rows = [];

    String dateFilter = '';
    if (_analyticsPeriod == 'weekly') {
      dateFilter = "AND ar.timestamp >= datetime('now', '-7 days')";
    } else if (_analyticsPeriod == 'monthly') {
      dateFilter = "AND ar.timestamp >= datetime('now', '-30 days')";
    } else if (_analyticsPeriod == 'yearly') {
      dateFilter = "AND ar.timestamp >= datetime('now', '-365 days')";
    }

    String fileName = '';
    if (_analyticsRole == 'students') {
      rows.add(['Student Name', 'Date', 'Status']);
      
      final results = await db.rawQuery('''
        SELECT s.name as student_name, ar.timestamp, ar.status
        FROM attendance_records ar
        INNER JOIN students s ON ar.student_id = s.id
        WHERE s.organization_id = ? $dateFilter
        ORDER BY ar.timestamp DESC
      ''', [org.id]);

      for (var row in results) {
        rows.add([
          row['student_name'],
          row['timestamp'],
          row['status'],
        ]);
      }
      fileName = '${org.name.replaceAll(' ', '_')}_Students_Attendance_$_analyticsPeriod.csv';
    } else {
      String empDateFilter = dateFilter.replaceAll('ar.timestamp', 'cl.clock_in');
      rows.add(['Employee Name', 'Clock In', 'Clock Out', 'Type']);
      
      final results = await db.rawQuery('''
        SELECT t.name as employee_name, cl.clock_in, cl.clock_out, cl.type
        FROM clock_logs cl
        INNER JOIN teachers t ON cl.teacher_id = t.id
        WHERE t.organization_id = ? AND cl.type = 'office' $empDateFilter
        ORDER BY cl.clock_in DESC
      ''', [org.id]);

      for (var row in results) {
        rows.add([
          row['employee_name'],
          row['clock_in'],
          row['clock_out'] ?? 'N/A',
          row['type'],
        ]);
      }
      fileName = '${org.name.replaceAll(' ', '_')}_Employees_ClockLogs_$_analyticsPeriod.csv';
    }

    if (rows.length <= 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No logs found for the selected period to export.')),
        );
      }
      return;
    }

    final String csv = const ListToCsvConverter().convert(rows);
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/$fileName';
    final file = File(path);
    await file.writeAsString(csv);

    await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: 'Exported ${_analyticsRole == 'students' ? 'Student Attendance' : 'Employee Clock Logs'} for ${org.name}'));
  }

  Widget _buildAnalyticsTab(bool isDark) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    // Compute Student metrics
    final int studPresent = _studentStats['PRESENT'] ?? 0;
    final int studLate = _studentStats['LATE'] ?? 0;
    final int studAbsent = _studentStats['ABSENT'] ?? 0;
    final int studTotal = studPresent + studLate + studAbsent;
    
    // Compute Employee metrics
    final int empIn = _employeeStats['CLOCKED_IN'] ?? 0;
    final int empOut = _employeeStats['CLOCKED_OUT'] ?? 0;
    final int empTotal = empIn + empOut;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner card with gradient background
          Container(
            padding: const EdgeInsets.all(AppSpace.xl),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [Colors.indigo.withValues(alpha: 0.15), Colors.purple.withValues(alpha: 0.05)]
                    : [Colors.indigo.withValues(alpha: 0.06), Colors.purple.withValues(alpha: 0.02)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: AppRadius.lgR,
              border: Border.all(color: Colors.indigo.withValues(alpha: isDark ? 0.3 : 0.15), width: 1.5),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.indigo.withValues(alpha: 0.12),
                  child: const Icon(Icons.analytics_rounded, color: Colors.indigo, size: 24),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Analytics & Operations',
                        style: AppType.display(context, fontSize: 17, weight: FontWeight.w800, color: Colors.indigo),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Detailed graphical insights of weekly activity rates and attendance logs.',
                        style: AppType.body(context, fontSize: 12.5, color: AppColors.textSecondary(isDark)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),

          // Role Switcher Segmented Button
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(
                value: 'students',
                label: Text('Students'),
                icon: Icon(Icons.school_rounded, size: 16),
              ),
              ButtonSegment<String>(
                value: 'employees',
                label: Text('Employees / Faculty'),
                icon: Icon(Icons.work_rounded, size: 16),
              ),
            ],
            selected: {_analyticsRole},
            onSelectionChanged: (newSelection) {
              setState(() {
                _analyticsRole = newSelection.first;
              });
            },
          ),
          const SizedBox(height: AppSpace.lg),

          // Period Selector (Full Width)
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(value: 'weekly', label: Text('Weekly', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
              ButtonSegment<String>(value: 'monthly', label: Text('Monthly', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
              ButtonSegment<String>(value: 'yearly', label: Text('Yearly', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
              ButtonSegment<String>(value: 'all', label: Text('Duration', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
            ],
            selected: {_analyticsPeriod},
            onSelectionChanged: (newSelection) {
              setState(() {
                _analyticsPeriod = newSelection.first;
              });
              _loadAllData();
            },
          ),
          const SizedBox(height: AppSpace.md),

          // Export CSV Action Button (Full Width)
          ElevatedButton.icon(
            onPressed: _exportAdminMetricsToCsv,
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Export CSV Report'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.smR),
            ),
          ),
          const SizedBox(height: AppSpace.lg),

          if (_analyticsRole == 'students') ...[
            // Student Overview Stats Card (Pie Chart & Summary)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.lgR,
                side: BorderSide(color: AppColors.border(isDark), width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ATTENDANCE COMPOSITION',
                      style: AppType.body(context, weight: FontWeight.w700, fontSize: 10, color: AppColors.textSecondary(isDark), letterSpacing: 0.5),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    if (studTotal == 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
                        child: Center(
                          child: Text(
                            'No student attendance logs recorded in this organization.',
                            style: AppType.body(context, fontSize: 13, color: AppColors.textTertiary(isDark)),
                          ),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            flex: 40,
                            child: SizedBox(
                              height: 120,
                              child: CustomPaint(
                                painter: CustomPieChartPainter(
                                  data: {
                                    'Present': studPresent.toDouble(),
                                    'Late': studLate.toDouble(),
                                    'Absent': studAbsent.toDouble(),
                                  },
                                  colors: {
                                    'Present': AppColors.success,
                                    'Late': AppColors.warning,
                                    'Absent': AppColors.danger,
                                  },
                                  surfaceColor: isDark ? AppColors.slate900 : Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpace.lg),
                          Expanded(
                            flex: 60,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLegendRow(AppColors.success, 'Present', studPresent, studTotal),
                                const SizedBox(height: 8),
                                _buildLegendRow(AppColors.warning, 'Late', studLate, studTotal),
                                const SizedBox(height: 8),
                                _buildLegendRow(AppColors.danger, 'Absent', studAbsent, studTotal),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpace.lg),

            // Student Trend Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.lgR,
                side: BorderSide(color: AppColors.border(isDark), width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Student Daily Compliance Trend',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: -0.2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Active compliance rate (Present + Late) over the last 7 active days',
                      style: TextStyle(color: AppColors.textTertiary(isDark), fontSize: 11.5),
                    ),
                    const SizedBox(height: 28),
                    if (_studentTrend.isEmpty)
                      SizedBox(
                        height: 120,
                        child: Center(
                          child: Text(
                            'Insufficient daily log data to draw trend.',
                            style: AppType.body(context, fontSize: 12.5, color: AppColors.textTertiary(isDark)),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 180,
                        width: double.maxFinite,
                        child: CustomPaint(
                          painter: AnalyticsPainter(
                            isDark: isDark,
                            dataPoints: _studentTrend.values.toList(),
                            labels: _studentTrend.keys.map((k) {
                              final dt = DateTime.tryParse(k);
                              return dt != null ? DateFormat.E().format(dt) : k;
                            }).toList(),
                            barColor: primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Employee Overview Stats Card (Pie Chart & Summary)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.lgR,
                side: BorderSide(color: AppColors.border(isDark), width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OFFICE WORKPLACE ATTENDANCE',
                      style: AppType.body(context, weight: FontWeight.w700, fontSize: 10, color: AppColors.textSecondary(isDark), letterSpacing: 0.5),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    if (empTotal == 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
                        child: Center(
                          child: Text(
                            'No office clock-in logs recorded in this organization.',
                            style: AppType.body(context, fontSize: 13, color: AppColors.textTertiary(isDark)),
                          ),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            flex: 40,
                            child: SizedBox(
                              height: 120,
                              child: CustomPaint(
                                painter: CustomPieChartPainter(
                                  data: {
                                    'Clocked In': empIn.toDouble(),
                                    'Clocked Out': empOut.toDouble(),
                                  },
                                  colors: {
                                    'Clocked In': AppColors.success,
                                    'Clocked Out': AppColors.slate400,
                                  },
                                  surfaceColor: isDark ? AppColors.slate900 : Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpace.lg),
                          Expanded(
                            flex: 60,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLegendRow(AppColors.success, 'Active Clocked-In', empIn, empTotal),
                                const SizedBox(height: 8),
                                _buildLegendRow(AppColors.slate400, 'Clocked-Out Logs', empOut, empTotal),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpace.lg),

            // Employee Trend Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.lgR,
                side: BorderSide(color: AppColors.border(isDark), width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Employee Active Clock-In Trend',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: -0.2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Distinct active employees clocking-in daily over the last 7 active days',
                      style: TextStyle(color: AppColors.textTertiary(isDark), fontSize: 11.5),
                    ),
                    const SizedBox(height: 28),
                    if (_employeeTrend.isEmpty)
                      SizedBox(
                        height: 120,
                        child: Center(
                          child: Text(
                            'Insufficient daily office log data to draw trend.',
                            style: AppType.body(context, fontSize: 12.5, color: AppColors.textTertiary(isDark)),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 180,
                        width: double.maxFinite,
                        child: CustomPaint(
                          painter: AnalyticsPainter(
                            isDark: isDark,
                            dataPoints: _employeeTrend.values.toList(),
                            labels: _employeeTrend.keys.map((k) {
                              final dt = DateTime.tryParse(k);
                              return dt != null ? DateFormat.E().format(dt) : k;
                            }).toList(),
                            barColor: AppColors.success,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLegendRow(Color color, String name, int count, int total) {
    final pct = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          '$name:',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
        const SizedBox(width: 4),
        Text(
          '$count ($pct%)',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildMiniMetricCard({
    required bool isDark,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: AppRadius.mdR,
        border: Border.all(color: AppColors.border(isDark), width: 1.5),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.10),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary(isDark),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(isDark),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _showStudentsInMembers = true;

  Widget _buildOverviewTab(bool isDark) {
    final theme = Theme.of(context);

    // Calculate metrics
    final totalStudents = _approvedStudents.length;
    final totalEmployees = _approvedEmployees.length;
    final pendingApprovals = _pendingTeachers.length + _pendingStudents.length;

    return FutureBuilder<List<Venue>>(
      future: VenueRepository().getAllVenues(organizationId: widget.admin.organizationId),
      builder: (context, snapshot) {
        final totalVenues = snapshot.data?.length ?? 0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome Banner Card
              Card(
                elevation: 0,
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.lgR,
                  side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.15), width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.xl),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: theme.colorScheme.primary,
                        child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 30),
                      ),
                      const SizedBox(width: AppSpace.xl),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dashboard Insights',
                              style: AppType.display(context, fontSize: 18, weight: FontWeight.w800, color: theme.colorScheme.primary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Real-time metrics for ${_organization?.name ?? "your organization"}.',
                              style: AppType.body(context, fontSize: 13, color: AppColors.textSecondary(isDark)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.lg),

              // Metrics Grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpace.md,
                crossAxisSpacing: AppSpace.md,
                childAspectRatio: 1.4,
                children: [
                  _buildMetricCard(
                    context,
                    title: 'Total Students',
                    value: '$totalStudents',
                    icon: Icons.school_rounded,
                    color: Colors.blue,
                    isDark: isDark,
                  ),
                  _buildMetricCard(
                    context,
                    title: 'Employees/Staff',
                    value: '$totalEmployees',
                    icon: Icons.work_rounded,
                    color: Colors.indigo,
                    isDark: isDark,
                  ),
                  _buildMetricCard(
                    context,
                    title: 'Geofence Venues',
                    value: '$totalVenues',
                    icon: Icons.pin_drop_rounded,
                    color: Colors.teal,
                    isDark: isDark,
                  ),
                  _buildMetricCard(
                    context,
                    title: 'Pending Approvals',
                    value: '$pendingApprovals',
                    icon: Icons.pending_rounded,
                    color: Colors.orange,
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.lg),

              // Quick Actions
              Text(
                'QUICK ACTIONS',
                style: AppType.body(context, fontSize: 11, weight: FontWeight.w700, color: AppColors.textSecondary(isDark), letterSpacing: 0.8),
              ),
              const SizedBox(height: AppSpace.sm),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.lgR,
                  side: BorderSide(color: AppColors.border(isDark), width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.add_location_alt_rounded, color: Colors.teal),
                        title: const Text('Configure Geofence Venues', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                        subtitle: const Text('Add or modify classrooms & offices', style: TextStyle(fontSize: 11.5)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => ManageVenuesScreen(organizationId: widget.admin.organizationId)),
                          );
                          _loadAllData();
                        },
                      ),
                      const Divider(indent: 56),
                      ListTile(
                        leading: const Icon(Icons.timer_outlined, color: Colors.orange),
                        title: const Text('Configure Timetable Shift Constraints', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                        subtitle: const Text('Define global operability hours', style: TextStyle(fontSize: 11.5)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                        onTap: () {
                          if (_organization != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => TimetableConstraintsScreen(organization: _organization!)),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showStudentMetricsDialog(Student student) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.lgR),
          title: Row(
            children: [
              const Icon(Icons.analytics_rounded, color: Colors.indigo, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${student.name} — Metrics',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: FutureBuilder<List<dynamic>>(
            future: Future.wait([
              DatabaseHelper.instance.database.then((db) => db.rawQuery('''
                SELECT status, COUNT(*) as count 
                FROM attendance_records 
                WHERE student_id = ? 
                GROUP BY status
              ''', [student.id])),
              DatabaseHelper.instance.database.then((db) => db.rawQuery('''
                SELECT DATE(timestamp) as date_day,
                       SUM(CASE WHEN status IN ('PRESENT', 'LATE') THEN 1 ELSE 0 END) * 1.0 / COUNT(*) as compliance_rate
                FROM attendance_records
                WHERE student_id = ?
                GROUP BY date_day
                ORDER BY date_day ASC
                LIMIT 7
              ''', [student.id])),
            ]),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return const SizedBox(
                  height: 100,
                  child: Center(child: Text('Error loading individual metrics')),
                );
              }

              final statsRows = snapshot.data![0] as List<Map<String, dynamic>>;
              final trendRows = snapshot.data![1] as List<Map<String, dynamic>>;

              int present = 0;
              int lateVal = 0;
              int absent = 0;
              for (var r in statsRows) {
                final status = (r['status'] as String).toUpperCase();
                final count = r['count'] as int;
                if (status == 'PRESENT') present = count;
                if (status == 'LATE') lateVal = count;
                if (status == 'ABSENT') absent = count;
              }
              final total = present + lateVal + absent;

              final trendMap = <String, double>{};
              for (var r in trendRows) {
                trendMap[r['date_day'] as String] = (r['compliance_rate'] as num).toDouble();
              }

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (total == 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No attendance logs recorded.',
                          style: TextStyle(color: AppColors.textTertiary(isDark), fontSize: 13),
                        ),
                      )
                    else ...[
                      SizedBox(
                        height: 120,
                        child: CustomPaint(
                          painter: CustomPieChartPainter(
                            data: {
                              'Present': present.toDouble(),
                              'Late': lateVal.toDouble(),
                              'Absent': absent.toDouble(),
                            },
                            colors: {
                              'Present': AppColors.success,
                              'Late': AppColors.warning,
                              'Absent': AppColors.danger,
                            },
                            surfaceColor: isDark ? AppColors.slate900 : Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildLegendDot(AppColors.success, 'P: $present'),
                          _buildLegendDot(AppColors.warning, 'L: $lateVal'),
                          _buildLegendDot(AppColors.danger, 'A: $absent'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Weekly Attendance Activity',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      if (trendMap.isEmpty)
                        Text(
                          'Insufficient daily trend data.',
                          style: TextStyle(color: AppColors.textTertiary(isDark), fontSize: 12),
                        )
                      else
                        SizedBox(
                          height: 140,
                          width: double.maxFinite,
                          child: CustomPaint(
                            painter: AnalyticsPainter(
                              isDark: isDark,
                              dataPoints: trendMap.values.toList(),
                              labels: trendMap.keys.map((k) {
                                final dt = DateTime.tryParse(k);
                                return dt != null ? DateFormat.E().format(dt) : k;
                              }).toList(),
                              barColor: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showEmployeeMetricsDialog(Teacher employee) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.lgR),
          title: Row(
            children: [
              const Icon(Icons.analytics_rounded, color: Colors.teal, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${employee.name} — Metrics',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: FutureBuilder<List<dynamic>>(
            future: Future.wait([
              DatabaseHelper.instance.database.then((db) => db.rawQuery('''
                SELECT clock_out, COUNT(*) as count 
                FROM clock_logs 
                WHERE teacher_id = ? AND type = 'office'
                GROUP BY (clock_out IS NULL)
              ''', [employee.id])),
              DatabaseHelper.instance.database.then((db) => db.rawQuery('''
                SELECT DATE(clock_in) as date_day, COUNT(*) as log_count
                FROM clock_logs
                WHERE teacher_id = ? AND type = 'office'
                GROUP BY date_day
                ORDER BY date_day ASC
                LIMIT 7
              ''', [employee.id])),
            ]),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return const SizedBox(
                  height: 100,
                  child: Center(child: Text('Error loading individual metrics')),
                );
              }

              final statsRows = snapshot.data![0] as List<Map<String, dynamic>>;
              final trendRows = snapshot.data![1] as List<Map<String, dynamic>>;

              int clockedIn = 0;
              int clockedOut = 0;
              for (var r in statsRows) {
                final clockOut = r['clock_out'] as String?;
                final count = r['count'] as int;
                if (clockOut == null || clockOut.isEmpty) {
                  clockedIn += count;
                } else {
                  clockedOut += count;
                }
              }
              final total = clockedIn + clockedOut;

              final trendMap = <String, double>{};
              for (var r in trendRows) {
                trendMap[r['date_day'] as String] = (r['log_count'] as num).toDouble();
              }

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (total == 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No office clock logs recorded.',
                          style: TextStyle(color: AppColors.textTertiary(isDark), fontSize: 13),
                        ),
                      )
                    else ...[
                      SizedBox(
                        height: 120,
                        child: CustomPaint(
                          painter: CustomPieChartPainter(
                            data: {
                              'Clocked In': clockedIn.toDouble(),
                              'Clocked Out': clockedOut.toDouble(),
                            },
                            colors: {
                              'Clocked In': AppColors.success,
                              'Clocked Out': AppColors.slate400,
                            },
                            surfaceColor: isDark ? AppColors.slate900 : Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildLegendDot(AppColors.success, 'Active In: $clockedIn'),
                          _buildLegendDot(AppColors.slate400, 'Logged Out: $clockedOut'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Weekly Active Clock-ins',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      if (trendMap.isEmpty)
                        Text(
                          'Insufficient daily trend data.',
                          style: TextStyle(color: AppColors.textTertiary(isDark), fontSize: 12),
                        )
                      else
                        SizedBox(
                          height: 140,
                          width: double.maxFinite,
                          child: CustomPaint(
                            painter: AnalyticsPainter(
                              isDark: isDark,
                              dataPoints: trendMap.values.toList(),
                              labels: trendMap.keys.map((k) {
                                final dt = DateTime.tryParse(k);
                                return dt != null ? DateFormat.E().format(dt) : k;
                              }).toList(),
                              barColor: Colors.teal,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.mdR,
        side: BorderSide(color: AppColors.border(isDark), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withValues(alpha: 0.1),
                  child: Icon(icon, color: color, size: 16),
                ),
                const Icon(Icons.trending_up_rounded, color: Colors.green, size: 14),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppType.display(context, fontSize: 22, weight: FontWeight.w800),
                ),
                Text(
                  title,
                  style: TextStyle(color: AppColors.textSecondary(isDark), fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersTab(bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.md),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: true,
                  label: Text('Students'),
                  icon: Icon(Icons.school_rounded, size: 16),
                ),
                ButtonSegment<bool>(
                  value: false,
                  label: Text('Employees'),
                  icon: Icon(Icons.work_rounded, size: 16),
                ),
              ],
              selected: {_showStudentsInMembers},
              onSelectionChanged: (newSelection) {
                setState(() {
                  _showStudentsInMembers = newSelection.first;
                });
              },
            ),
          ),
        ),
        Expanded(
          child: _showStudentsInMembers ? _buildStudentsList(isDark) : _buildEmployeesList(isDark),
        ),
      ],
    );
  }

  Widget _buildStudentsList(bool isDark) {
    if (_approvedStudents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/lottie/register.json',
                height: 140,
                width: 140,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.people_outline_rounded,
                  size: 64,
                  color: AppColors.slate400,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No approved students yet',
                style: AppType.display(context, fontSize: 15, weight: FontWeight.w600, color: AppColors.textPrimary(isDark)),
              ),
            ],
          ),
        ),
      );
    }

    final totalRecords = _approvedStudents.length;
    final totalPages = (_approvedStudents.length / _studentPageSize).ceil();
    final startIndex = _studentPage * _studentPageSize;
    final endIndex = (startIndex + _studentPageSize) < totalRecords ? (startIndex + _studentPageSize) : totalRecords;
    final pageRecords = _approvedStudents.sublist(startIndex, endIndex);

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            itemCount: pageRecords.length,
            itemBuilder: (context, index) {
              final student = pageRecords[index];
              return Card(
                margin: const EdgeInsets.only(bottom: AppSpace.xs),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.mdR,
                  side: BorderSide(color: AppColors.border(isDark), width: 1),
                ),
                child: ListTile(
                  dense: true,
                  onTap: () => _showStudentMetricsDialog(student),
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                    child: const Icon(Icons.school_rounded, size: 16),
                  ),
                  title: Text(
                    student.name,
                    style: AppType.display(context, fontSize: 13.5, weight: FontWeight.w700, color: AppColors.textPrimary(isDark)),
                  ),
                  subtitle: Text(
                    'Device ID: ${student.deviceAppId.isNotEmpty ? student.deviceAppId.substring(0, student.deviceAppId.length.clamp(0, 16)) : "N/A"}',
                    style: AppType.data(context, fontSize: 11, color: AppColors.textSecondary(isDark)),
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 18),
                    onSelected: (val) {
                      if (val == 'edit') {
                        _showEditStudentDialog(student);
                      } else if (val == 'suspend') {
                        _suspendStudent(student);
                      } else if (val == 'delete') {
                        _deleteStudent(student);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 16),
                            SizedBox(width: 8),
                            Text('Edit Details'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'suspend',
                        child: Row(
                          children: [
                            Icon(Icons.block_rounded, size: 16, color: Colors.amber),
                            SizedBox(width: 8),
                            Text('Suspend/Block'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_forever_rounded, size: 16, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        _buildPaginationFooter(_studentPage, totalPages, totalRecords, startIndex, endIndex, (newPage) {
          setState(() {
            _studentPage = newPage;
          });
        }, isDark),
      ],
    );
  }

  Widget _buildEmployeesList(bool isDark) {
    if (_approvedEmployees.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/lottie/register.json',
                height: 140,
                width: 140,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.work_outline_rounded,
                  size: 64,
                  color: AppColors.slate400,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No approved employees yet',
                style: AppType.display(context, fontSize: 15, weight: FontWeight.w600, color: AppColors.textPrimary(isDark)),
              ),
            ],
          ),
        ),
      );
    }

    final totalRecords = _approvedEmployees.length;
    final totalPages = (_approvedEmployees.length / _employeePageSize).ceil();
    final startIndex = _employeePage * _employeePageSize;
    final endIndex = (startIndex + _employeePageSize) < totalRecords ? (startIndex + _employeePageSize) : totalRecords;
    final pageRecords = _approvedEmployees.sublist(startIndex, endIndex);

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            itemCount: pageRecords.length,
            itemBuilder: (context, index) {
              final employee = pageRecords[index];
              return Card(
                margin: const EdgeInsets.only(bottom: AppSpace.xs),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.mdR,
                  side: BorderSide(color: AppColors.border(isDark), width: 1),
                ),
                child: InkWell(
                  borderRadius: AppRadius.mdR,
                  onTap: () => _showEmployeeMetricsDialog(employee),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                        child: const Icon(Icons.work_rounded, size: 16),
                      ),
                      const SizedBox(width: AppSpace.md),
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    employee.name,
                                    style: AppType.display(context, fontSize: 13.5, weight: FontWeight.w700, color: AppColors.textPrimary(isDark)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.indigo.withValues(alpha: 0.08),
                                    borderRadius: AppRadius.smR,
                                  ),
                                  child: Text(
                                    employee.role.toUpperCase(),
                                    style: const TextStyle(color: AppColors.indigo, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              employee.email,
                              style: AppType.data(context, fontSize: 11, color: AppColors.textSecondary(isDark)),
                            ),
                            const SizedBox(height: 4),
                            // Office allocation row
                            FutureBuilder<Venue?>(
                              future: employee.officeVenueId != null
                                  ? VenueRepository().getVenueById(employee.officeVenueId!)
                                  : Future.value(null),
                              builder: (context, snapshot) {
                                final venue = snapshot.data;
                                final allocated = venue != null;
                                return Row(
                                  children: [
                                    if (allocated) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.teal.withValues(alpha: 0.08),
                                          borderRadius: AppRadius.smR,
                                          border: Border.all(color: Colors.teal.withValues(alpha: 0.2), width: 1),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.business_center_rounded, size: 11, color: Colors.teal),
                                            const SizedBox(width: 4),
                                            Text(
                                              venue.name,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.teal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Spacer(),
                                    ] else ...[
                                      const Icon(Icons.no_meeting_room_rounded, size: 12, color: Colors.orange),
                                      const SizedBox(width: 4),
                                      const Expanded(
                                        child: Text(
                                          'No office allocated',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.orange,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                    // Allocate Office inline button
                                    InkWell(
                                      borderRadius: AppRadius.smR,
                                      onTap: () => _showAllocateOfficeDialog(employee),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.teal.withValues(alpha: 0.08),
                                          borderRadius: AppRadius.smR,
                                          border: Border.all(color: Colors.teal.withValues(alpha: 0.3), width: 1),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.add_location_alt_rounded, size: 11, color: Colors.teal),
                                            const SizedBox(width: 4),
                                            Text(
                                              allocated ? 'Reallocate Office' : 'Allocate Office',
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.teal),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      // 3-dot popup menu for edit/suspend/delete
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, size: 18),
                        onSelected: (val) {
                          if (val == 'edit') {
                            _showEditEmployeeDialog(employee);
                          } else if (val == 'suspend') {
                            _suspendEmployee(employee);
                          } else if (val == 'delete') {
                            _deleteEmployee(employee);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_rounded, size: 16),
                                SizedBox(width: 8),
                                Text('Edit Details'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'suspend',
                            child: Row(
                              children: [
                                Icon(Icons.block_rounded, size: 16, color: Colors.amber),
                                SizedBox(width: 8),
                                Text('Suspend/Block'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_forever_rounded, size: 16, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
            },
          ),
        ),
        _buildPaginationFooter(_employeePage, totalPages, totalRecords, startIndex, endIndex, (newPage) {
          setState(() {
            _employeePage = newPage;
          });
        }, isDark),
      ],
    );
  }

  Widget _buildPaginationFooter(
    int currentPage,
    int totalPages,
    int totalRecords,
    int startIndex,
    int endIndex,
    Function(int) onPageChanged,
    bool isDark,
  ) {
    if (totalRecords == 0) return const SizedBox();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${startIndex + 1} – $endIndex of $totalRecords',
            style: AppType.data(context, fontSize: 11, weight: FontWeight.w600, color: AppColors.textSecondary(isDark)),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                onPressed: currentPage > 0 ? () => onPageChanged(currentPage - 1) : null,
              ),
              Text(
                '${currentPage + 1} / $totalPages',
                style: AppType.data(context, fontSize: 12, weight: FontWeight.w700, color: AppColors.textPrimary(isDark)),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                onPressed: currentPage < totalPages - 1 ? () => onPageChanged(currentPage + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditStudentDialog(Student student) {
    final nameController = TextEditingController(text: student.name);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Student Details'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => v == null || v.isEmpty ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 12),
              Text(
                'Device ID: ${student.deviceAppId.isNotEmpty ? student.deviceAppId : "Not bound"}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                final updatedStudent = Student(
                  id: student.id,
                  organizationId: student.organizationId,
                  courseId: student.courseId,
                  name: nameController.text.trim(),
                  deviceAppId: student.deviceAppId,
                  isApproved: student.isApproved,
                );
                await _studentRepo.updateStudent(updatedStudent);
                _loadAllData();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditEmployeeDialog(Teacher employee) async {
    final nameController = TextEditingController(text: employee.name);
    final emailController = TextEditingController(text: employee.email);
    String tempRole = employee.role;
    int? tempSelectedVenueId = employee.officeVenueId;
    final formKey = GlobalKey<FormState>();

    // Only office-type venues can be allocated as offices
    final allVenues = await VenueRepository().getAllVenues(organizationId: widget.admin.organizationId);
    final venues = allVenues
        .where((v) => v.category == 'office' || v.category == 'staff_room')
        .toList();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Edit Employee Details'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (v) => v == null || v.isEmpty ? 'Please enter a name' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) => v == null || v.isEmpty ? 'Please enter an email' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: tempRole,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: const [
                        DropdownMenuItem(value: 'teacher', child: Text('Teacher/Educator')),
                        DropdownMenuItem(value: 'employee', child: Text('Staff/Employee')),
                        DropdownMenuItem(value: 'admin', child: Text('Administrator')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            tempRole = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int?>(
                      initialValue: tempSelectedVenueId,
                      decoration: const InputDecoration(
                        labelText: 'Office / Staff Room (Optional)',
                        prefixIcon: Icon(Icons.business_center_rounded),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('None (Geofence Disabled)'),
                        ),
                        ...venues.map((v) => DropdownMenuItem<int?>(
                              value: v.id,
                              child: Row(
                                children: [
                                  Icon(
                                    v.category == 'staff_room'
                                        ? Icons.meeting_room_rounded
                                        : Icons.business_center_rounded,
                                    size: 14,
                                    color: v.category == 'staff_room' ? Colors.teal : Colors.indigo,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(v.name),
                                ],
                              ),
                            )),
                      ],
                      onChanged: (val) {
                        setDialogState(() {
                          tempSelectedVenueId = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(dialogContext);
                    final updatedEmployee = Teacher(
                      id: employee.id,
                      organizationId: employee.organizationId,
                      name: nameController.text.trim(),
                      email: employee.email,
                      role: tempRole,
                      deviceAppId: employee.deviceAppId,
                      isApproved: employee.isApproved,
                      officeVenueId: tempSelectedVenueId,
                    );
                    await _teacherRepo.updateTeacher(updatedEmployee);
                    await _teacherRepo.updateTeacherOfficeVenue(employee.id!, tempSelectedVenueId);
                    _loadAllData();
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Shows the allocate/change office venue dialog.
  /// Only shows venue of category 'office' or 'staff_room'.
  void _showAllocateOfficeDialog(Teacher employee) async {
    final officeVenues = await VenueRepository().getAllVenues(organizationId: widget.admin.organizationId);
    if (!mounted) return;

    int? tempSelectedVenueId = employee.officeVenueId;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: AppRadius.lgR),
            title: Row(
              children: [
                const Icon(Icons.add_location_alt_rounded, color: Colors.teal, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Allocate Office — ${employee.name}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select an office or staff room. The employee will only be able to clock in/out from within that geofenced boundary.',
                    style: TextStyle(fontSize: 12.5),
                  ),
                  const SizedBox(height: 16),
                  if (officeVenues.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.08),
                        borderRadius: AppRadius.mdR,
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No venues found. Create a venue using the Venues Manager first.',
                              style: TextStyle(fontSize: 12, color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    DropdownButtonFormField<int?>(
                      initialValue: tempSelectedVenueId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Office / Staff Room',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.business_center_rounded),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('None (Clock-in disabled)'),
                        ),
                        ...officeVenues.map((v) => DropdownMenuItem<int?>(
                              value: v.id,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    v.category == 'staff_room'
                                        ? Icons.meeting_room_rounded
                                        : v.category == 'office'
                                            ? Icons.business_center_rounded
                                            : Icons.class_rounded,
                                    size: 14,
                                    color: v.category == 'staff_room'
                                        ? Colors.teal
                                        : v.category == 'office'
                                            ? Colors.indigo
                                            : Colors.blueGrey,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(v.name, overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            )),
                      ],
                      onChanged: (val) {
                        setDialogState(() {
                          tempSelectedVenueId = val;
                        });
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.save_rounded, size: 16),
                label: const Text('Save Allocation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
                onPressed: officeVenues.isEmpty
                    ? null
                    : () async {
                        Navigator.of(dialogContext).pop();
                        await _teacherRepo.updateTeacherOfficeVenue(employee.id!, tempSelectedVenueId);
                        _loadAllData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                tempSelectedVenueId == null
                                    ? 'Office allocation cleared for ${employee.name}.'
                                    : 'Office allocated to ${employee.name} successfully!',
                              ),
                              backgroundColor: Colors.teal,
                            ),
                          );
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  void _suspendStudent(Student student) async {
    await _studentRepo.suspendStudent(student.id!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Suspended student ${student.name} successfully!'), backgroundColor: Colors.amber[800]),
      );
    }
    _loadAllData();
  }

  void _suspendEmployee(Teacher employee) async {
    await _teacherRepo.suspendTeacher(employee.id!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Suspended employee ${employee.name} successfully!'), backgroundColor: Colors.amber[800]),
      );
    }
    _loadAllData();
  }

  void _deleteStudent(Student student) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student'),
        content: Text('Are you sure you want to permanently delete student "${student.name}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _studentRepo.deleteStudent(student.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student deleted successfully!'), backgroundColor: Colors.red),
        );
      }
      _loadAllData();
    }
  }

  void _deleteEmployee(Teacher employee) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Employee'),
        content: Text('Are you sure you want to permanently delete employee "${employee.name}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _teacherRepo.rejectEmployee(employee.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employee deleted successfully!'), backgroundColor: Colors.red),
        );
      }
      _loadAllData();
    }
  }

  // ignore: unused_element
  Widget _buildOrgInfoRow(BuildContext context, String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: AppColors.textSecondary(isDark)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class AnalyticsPainter extends CustomPainter {
  final bool isDark;
  final List<double> dataPoints;
  final List<String> labels;
  final Color barColor;

  AnalyticsPainter({
    required this.isDark,
    required this.dataPoints,
    required this.labels,
    this.barColor = Colors.indigo,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
    );

    final double width = size.width;
    final double height = size.height - 30; // Leave space for labels
    final double spacing = width / dataPoints.length;
    final double barWidth = spacing * 0.45;

    // Draw horizontal gridlines and percentage values
    final gridPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const double gridLevels = 4;
    for (int j = 1; j <= gridLevels; j++) {
      final double yLevel = height * (1 - (j / gridLevels));
      canvas.drawLine(Offset(0, yLevel), Offset(width, yLevel), gridPaint);
      
      // Percentage indicator text
      textPainter.text = TextSpan(
        text: '${(j * 25).toInt()}%',
        style: TextStyle(
          color: isDark ? Colors.grey[600] : Colors.grey[400],
          fontSize: 8.5,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(2, yLevel - 12));
    }

    final bgPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < dataPoints.length; i++) {
      final double x = spacing * i + (spacing - barWidth) / 2;
      final double y = height - (height * dataPoints[i]);

      // Background tracking track
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 0, barWidth, height),
          const Radius.circular(8),
        ),
        bgPaint,
      );

      // Value bar with gradient
      final paint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(x, height),
          Offset(x, y),
          [
            barColor.withValues(alpha: 0.4),
            barColor,
          ],
        )
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, height * dataPoints[i]),
          const Radius.circular(8),
        ),
        paint,
      );

      // Value label on top of bar
      final pctText = '${(dataPoints[i] * 100).toStringAsFixed(0)}%';
      textPainter.text = TextSpan(
        text: pctText,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x + (barWidth - textPainter.width) / 2, (y - 14).clamp(4.0, height)),
      );

      // Label text
      textPainter.text = TextSpan(
        text: labels[i],
        style: TextStyle(
          color: isDark ? Colors.grey[400] : Colors.grey[700],
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x + (barWidth - textPainter.width) / 2, height + 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TimetableConstraintsScreen extends StatefulWidget {
  final Organization organization;
  const TimetableConstraintsScreen({super.key, required this.organization});

  @override
  State<TimetableConstraintsScreen> createState() => _TimetableConstraintsScreenState();
}

class _TimetableConstraintsScreenState extends State<TimetableConstraintsScreen>
    with SingleTickerProviderStateMixin {
  final _constraintsRepo = TimetableConstraintsRepository();

  // Time-of-day state (native pickers)
  TimeOfDay _shiftStart  = const TimeOfDay(hour: 8,  minute: 0);
  TimeOfDay _shiftEnd    = const TimeOfDay(hour: 17, minute: 0);
  TimeOfDay _breakStart  = const TimeOfDay(hour: 10, minute: 30);
  TimeOfDay _lunchStart  = const TimeOfDay(hour: 13, minute: 0);
  TimeOfDay _assemblyStart = const TimeOfDay(hour: 8, minute: 0);

  // Duration controllers
  final _breakDurController    = TextEditingController(text: '30');
  final _lunchDurController    = TextEditingController(text: '60');
  final _assemblyDurController = TextEditingController(text: '15');

  bool _isLoading = true;
  bool _isSaving  = false;

  late final AnimationController _animController;
  late final Animation<double>   _fadeIn;

  // ── Optional period toggles ──────────────────────────────────────────────
  bool _hasBreak    = true;
  bool _hasLunch    = true;
  bool _hasAssembly = false;

  // ── Day-of-week overrides ────────────────────────────────────────────────
  List<TimetableDayOverride> _dayOverrides = [];
  // Track which days have custom hours expanded
  final Set<int> _expandedCustomHours = {};
  // Label text controllers keyed by dayOfWeek
  final Map<int, TextEditingController> _labelControllers = {};

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadConstraints();
  }

  @override
  void dispose() {
    _breakDurController.dispose();
    _lunchDurController.dispose();
    _assemblyDurController.dispose();
    for (final c in _labelControllers.values) {
      c.dispose();
    }
    _animController.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  TimeOfDay _parseTime(String? hhmm, TimeOfDay fallback) {
    if (hhmm == null || hhmm.isEmpty) return fallback;
    final parts = hhmm.split(':');
    if (parts.length != 2) return fallback;
    return TimeOfDay(hour: int.tryParse(parts[0]) ?? fallback.hour,
                     minute: int.tryParse(parts[1]) ?? fallback.minute);
  }

  String _formatTod(TimeOfDay tod) =>
      '${tod.hour.toString().padLeft(2, '0')}:${tod.minute.toString().padLeft(2, '0')}';

  String _todDisplay(TimeOfDay tod) {
    final h = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final ampm = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:${tod.minute.toString().padLeft(2, '0')} $ampm';
  }

  // ── Data ─────────────────────────────────────────────────────────────────

  Future<void> _loadConstraints() async {
    try {
      final c = await _constraintsRepo.getConstraints(widget.organization.id!);
      if (c != null) {
        setState(() {
          _shiftStart    = _parseTime(c.startTime,    _shiftStart);
          _shiftEnd      = _parseTime(c.endTime,      _shiftEnd);
          _breakStart    = _parseTime(c.breakStart,   _breakStart);
          _lunchStart    = _parseTime(c.lunchStart,   _lunchStart);
          _assemblyStart = _parseTime(c.assemblyStart,_assemblyStart);

          _breakDurController.text    = c.breakDurationMins?.toString()    ?? '30';
          _lunchDurController.text    = c.lunchDurationMins?.toString()    ?? '60';
          _assemblyDurController.text = c.assemblyDurationMins?.toString() ?? '15';

          _hasBreak    = c.breakStart != null;
          _hasLunch    = c.lunchStart != null;
          _hasAssembly = c.assemblyStart != null;
        });
      }
    } catch (_) {}

    // Load day overrides
    try {
      final overrides = await _constraintsRepo
          .getOrBuildDefaultOverrides(widget.organization.id!);
      // Build label controllers
      for (final o in overrides) {
        _labelControllers[o.dayOfWeek] =
            TextEditingController(text: o.label ?? '');
        // Auto-expand custom hours if already set
        if (o.customStartTime != null || o.customEndTime != null) {
          _expandedCustomHours.add(o.dayOfWeek);
        }
      }
      setState(() => _dayOverrides = overrides);
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
      _animController.forward();
    }
  }

  Future<void> _saveConstraints() async {
    setState(() => _isSaving = true);
    try {
      // Save global constraints
      final c = TimetableConstraints(
        organizationId: widget.organization.id!,
        startTime:  _formatTod(_shiftStart),
        endTime:    _formatTod(_shiftEnd),
        breakStart: _hasBreak    ? _formatTod(_breakStart)   : null,
        breakDurationMins:    _hasBreak    ? int.tryParse(_breakDurController.text)    : null,
        lunchStart: _hasLunch    ? _formatTod(_lunchStart)   : null,
        lunchDurationMins:    _hasLunch    ? int.tryParse(_lunchDurController.text)    : null,
        assemblyStart: _hasAssembly ? _formatTod(_assemblyStart) : null,
        assemblyDurationMins: _hasAssembly ? int.tryParse(_assemblyDurController.text) : null,
      );
      await _constraintsRepo.saveConstraints(c);

      // Save day overrides (sync label text into the model)
      final updatedOverrides = _dayOverrides.map((o) {
        final labelText = _labelControllers[o.dayOfWeek]?.text.trim();
        return o.copyWith(
          label: (labelText != null && labelText.isNotEmpty) ? labelText : null,
          clearLabel: labelText == null || labelText.isEmpty,
        );
      }).toList();
      await _constraintsRepo.saveAllDayOverrides(updatedOverrides);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Timetable constraints saved!'),
            ]),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.mdR),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Time picker ──────────────────────────────────────────────────────────

  Future<void> _pickTime(
    TimeOfDay current,
    void Function(TimeOfDay) onPicked,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) setState(() => onPicked(picked));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme    = Theme.of(context);
    final isDark   = theme.brightness == Brightness.dark;
    final primary  = theme.colorScheme.primary;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeIn,
              child: CustomScrollView(
                slivers: [
                  // ── Gradient app bar ──────────────────────────────────────
                  SliverAppBar(
                    expandedHeight: 150.0,
                    pinned: true,
                    backgroundColor: isDark ? AppColors.slate950 : primary,
                    foregroundColor: Colors.white,
                    title: Text(
                      'Timetable Constraints',
                      style: AppType.display(context, fontSize: 18, weight: FontWeight.w700, color: Colors.white),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          SvgPicture.asset(
                            'assets/images/banner.svg',
                            fit: BoxFit.cover,
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withValues(alpha: 0.45),
                                  Colors.black.withValues(alpha: 0.1),
                                  Colors.black.withValues(alpha: 0.6),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(AppSpace.xl),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TIMETABLE RULES',
                                  style: AppType.body(
                                    context,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    weight: FontWeight.w700,
                                    fontSize: 10,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.organization.name,
                                  style: AppType.body(
                                    context,
                                    fontSize: 12.5,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Content ───────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpace.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Visual timeline preview
                          _buildTimelinePreview(isDark, primary),
                          const SizedBox(height: AppSpace.xl),

                          // ── Work shift section ───────────────────────────
                          _buildSectionCard(
                            isDark: isDark,
                            icon: Icons.work_history_rounded,
                            color: primary,
                            title: 'Work Shift',
                            subtitle: 'Set the official start and end of the working day',
                            children: [
                              Row(children: [
                                Expanded(child: _buildTimeTile(
                                  isDark: isDark,
                                  label: 'Shift Start',
                                  tod: _shiftStart,
                                  color: Colors.green,
                                  onTap: () => _pickTime(_shiftStart, (t) => _shiftStart = t),
                                )),
                                const SizedBox(width: 12),
                                Expanded(child: _buildTimeTile(
                                  isDark: isDark,
                                  label: 'Shift End',
                                  tod: _shiftEnd,
                                  color: Colors.red,
                                  onTap: () => _pickTime(_shiftEnd, (t) => _shiftEnd = t),
                                )),
                              ]),
                            ],
                          ),
                          const SizedBox(height: AppSpace.lg),

                          // ── Break section ─────────────────────────────────
                          _buildSectionCard(
                            isDark: isDark,
                            icon: Icons.free_breakfast_rounded,
                            color: Colors.orange,
                            title: 'Morning Break',
                            subtitle: 'Optional short break between classes',
                            toggle: _hasBreak,
                            onToggle: (v) => setState(() => _hasBreak = v),
                            children: _hasBreak ? [
                              Row(children: [
                                Expanded(child: _buildTimeTile(
                                  isDark: isDark,
                                  label: 'Break Start',
                                  tod: _breakStart,
                                  color: Colors.orange,
                                  onTap: () => _pickTime(_breakStart, (t) => _breakStart = t),
                                )),
                                const SizedBox(width: 12),
                                Expanded(child: _buildDurationField(
                                  isDark: isDark,
                                  label: 'Duration',
                                  controller: _breakDurController,
                                  color: Colors.orange,
                                )),
                              ]),
                            ] : [],
                          ),
                          const SizedBox(height: AppSpace.lg),

                          // ── Lunch section ─────────────────────────────────
                          _buildSectionCard(
                            isDark: isDark,
                            icon: Icons.lunch_dining_rounded,
                            color: Colors.deepOrange,
                            title: 'Lunch Break',
                            subtitle: 'Midday break for meals',
                            toggle: _hasLunch,
                            onToggle: (v) => setState(() => _hasLunch = v),
                            children: _hasLunch ? [
                              Row(children: [
                                Expanded(child: _buildTimeTile(
                                  isDark: isDark,
                                  label: 'Lunch Start',
                                  tod: _lunchStart,
                                  color: Colors.deepOrange,
                                  onTap: () => _pickTime(_lunchStart, (t) => _lunchStart = t),
                                )),
                                const SizedBox(width: 12),
                                Expanded(child: _buildDurationField(
                                  isDark: isDark,
                                  label: 'Duration',
                                  controller: _lunchDurController,
                                  color: Colors.deepOrange,
                                )),
                              ]),
                            ] : [],
                          ),
                          const SizedBox(height: AppSpace.lg),

                          // ── Assembly section ──────────────────────────────
                          _buildSectionCard(
                            isDark: isDark,
                            icon: Icons.groups_rounded,
                            color: Colors.purple,
                            title: 'Assembly / Morning Meeting',
                            subtitle: 'Start-of-day gathering period',
                            toggle: _hasAssembly,
                            onToggle: (v) => setState(() => _hasAssembly = v),
                            children: _hasAssembly ? [
                              Row(children: [
                                Expanded(child: _buildTimeTile(
                                  isDark: isDark,
                                  label: 'Assembly Start',
                                  tod: _assemblyStart,
                                  color: Colors.purple,
                                  onTap: () => _pickTime(_assemblyStart, (t) => _assemblyStart = t),
                                )),
                                const SizedBox(width: 12),
                                Expanded(child: _buildDurationField(
                                  isDark: isDark,
                                  label: 'Duration',
                                  controller: _assemblyDurController,
                                  color: Colors.purple,
                                )),
                              ]),
                            ] : [],
                          ),
                          const SizedBox(height: AppSpace.lg),

                          // ── Day Schedule section ──────────────────────────
                          _buildDayScheduleSection(isDark, primary),
                          const SizedBox(height: AppSpace.xxl),

                          // ── Save button ───────────────────────────────────
                          Container(
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [primary, Color.lerp(primary, Colors.purple, 0.55)!],
                              ),
                              borderRadius: AppRadius.lgR,
                              boxShadow: [
                                BoxShadow(
                                  color: primary.withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: AppRadius.lgR,
                                onTap: _isSaving ? null : _saveConstraints,
                                child: Center(
                                  child: _isSaving
                                      ? const SizedBox(
                                          width: 22, height: 22,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                        )
                                      : const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.save_rounded, color: Colors.white, size: 20),
                                            SizedBox(width: 10),
                                            Text(
                                              'Save Constraints',
                                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpace.xxl),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ── Visual timeline preview ───────────────────────────────────────────────

  Widget _buildTimelinePreview(bool isDark, Color primary) {
    final startMins = _shiftStart.hour * 60 + _shiftStart.minute;
    final endMins   = _shiftEnd.hour   * 60 + _shiftEnd.minute;
    final total     = (endMins - startMins).clamp(1, 1440).toDouble();

    List<({double start, double width, Color color, String label})> segments = [];

    void addSeg(TimeOfDay tod, int dur, Color color, String label) {
      final s = (tod.hour * 60 + tod.minute - startMins).clamp(0, endMins - startMins).toDouble();
      final w = dur.clamp(0, (endMins - startMins) - s.toInt()).toDouble();
      if (w > 0) segments.add((start: s, width: w, color: color, label: label));
    }

    if (_hasBreak)    addSeg(_breakStart,    int.tryParse(_breakDurController.text)    ?? 30, Colors.orange,     'Break');
    if (_hasLunch)    addSeg(_lunchStart,    int.tryParse(_lunchDurController.text)    ?? 60, Colors.deepOrange, 'Lunch');
    if (_hasAssembly) addSeg(_assemblyStart, int.tryParse(_assemblyDurController.text) ?? 15, Colors.purple,     'Assembly');

    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: AppRadius.lgR,
        border: Border.all(color: AppColors.border(isDark)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.view_timeline_rounded, size: 18, color: primary),
            const SizedBox(width: 8),
            Text(
              'DAILY SCHEDULE PREVIEW',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: primary, letterSpacing: 1.0),
            ),
          ]),
          const SizedBox(height: 14),
          // Timeline bar
          LayoutBuilder(builder: (context, constraints) {
            final barW = constraints.maxWidth;
            return Stack(
              children: [
                // Base bar
                Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate700 : AppColors.slate100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                // Work hours (full green tint)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                // Segments
                ...segments.map((seg) {
                  final left  = (seg.start  / total * barW).clamp(0.0, barW);
                  final width = (seg.width  / total * barW).clamp(4.0, barW - left);
                  return Positioned(
                    left: left,
                    width: width,
                    top: 0,
                    bottom: 0,
                    child: Tooltip(
                      message: seg.label,
                      child: Container(
                        decoration: BoxDecoration(
                          color: seg.color.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.center,
                        child: width > 36
                            ? Text(
                                seg.label,
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                                overflow: TextOverflow.clip,
                              )
                            : const SizedBox(),
                      ),
                    ),
                  );
                }),
              ],
            );
          }),
          const SizedBox(height: 8),
          // Time labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_todDisplay(_shiftStart),
                   style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.green[700])),
              Text(_todDisplay(_shiftEnd),
                   style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.red[700])),
            ],
          ),
          if (segments.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: segments.map((s) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(s.label, style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary(isDark), fontWeight: FontWeight.w600)),
                ],
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ── Section card widget ───────────────────────────────────────────────────

  Widget _buildSectionCard({
    required bool isDark,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required List<Widget> children,
    bool? toggle,
    void Function(bool)? onToggle,
  }) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate800 : Colors.white,
          borderRadius: AppRadius.lgR,
          border: Border.all(color: AppColors.border(isDark)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: AppRadius.mdR,
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                             style: AppType.display(context, fontSize: 14, weight: FontWeight.w700,
                                                    color: AppColors.textPrimary(isDark))),
                        Text(subtitle,
                             style: AppType.body(context, fontSize: 11.5, color: AppColors.textSecondary(isDark))),
                      ],
                    ),
                  ),
                  if (toggle != null && onToggle != null)
                    Switch(
                      value: toggle,
                      onChanged: onToggle,
                      activeThumbColor: color,
                    ),
                ],
              ),
            ),
            // Fields (animated collapse via AnimatedSize parent)
            if (children.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border(isDark))),
                ),
                padding: const EdgeInsets.all(AppSpace.lg),
                child: Column(children: children),
              ),
          ],
        ),
      ),
    );
  }

  // ── Day Schedule section ──────────────────────────────────────────────────

  Widget _buildDayScheduleSection(bool isDark, Color primary) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.12),
                borderRadius: AppRadius.smR,
              ),
              child: const Icon(Icons.calendar_view_week_rounded, color: Colors.teal, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Day Schedule',
                      style: AppType.display(context,
                          fontSize: 15, weight: FontWeight.w700)),
                  Text('Configure working days and custom hours per day',
                      style: AppType.body(context,
                          fontSize: 12,
                          color: AppColors.textSecondary(isDark))),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Day cards
        ..._dayOverrides.map((override) => _buildDayCard(override, isDark, primary, theme)),
      ],
    );
  }

  Widget _buildDayCard(
    TimetableDayOverride override,
    bool isDark,
    Color primary,
    ThemeData theme,
  ) {
    final isWeekend = override.dayOfWeek >= 6;
    final dayColor  = isWeekend ? Colors.blueGrey : Colors.teal;
    final isWorking = override.isWorkingDay;
    final hasCustom = _expandedCustomHours.contains(override.dayOfWeek);

    final customStart = override.customStartTime != null
        ? _parseTime(override.customStartTime, _shiftStart)
        : _shiftStart;
    final customEnd = override.customEndTime != null
        ? _parseTime(override.customEndTime, _shiftEnd)
        : _shiftEnd;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: AppRadius.mdR,
        border: Border.all(
          color: isWorking
              ? dayColor.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Day chip
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: isWorking
                        ? dayColor.withValues(alpha: 0.12)
                        : Colors.red.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      override.dayShort.substring(0, 2),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isWorking ? dayColor : Colors.red,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(override.dayName,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700)),
                      if (isWorking && !hasCustom)
                        Text(
                          'Global hours: ${_todDisplay(_shiftStart)} – ${_todDisplay(_shiftEnd)}',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary(isDark)),
                        )
                      else if (!isWorking)
                        Text(
                          'No classes scheduled',
                          style: TextStyle(
                              fontSize: 11, color: Colors.red.withValues(alpha: 0.8)),
                        ),
                    ],
                  ),
                ),
                // Working day toggle
                GestureDetector(
                  onTap: () {
                    setState(() {
                      final idx = _dayOverrides.indexWhere(
                          (o) => o.dayOfWeek == override.dayOfWeek);
                      if (idx != -1) {
                        _dayOverrides[idx] = override.copyWith(
                            isWorkingDay: !isWorking);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isWorking
                          ? dayColor.withValues(alpha: 0.12)
                          : Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isWorking ? dayColor : Colors.red,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isWorking
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          size: 13,
                          color: isWorking ? dayColor : Colors.red,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isWorking ? 'Working' : 'Off',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isWorking ? dayColor : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Expandable body (only when working)
          if (isWorking) ...[
            const Divider(height: 1, indent: 14, endIndent: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: Column(
                children: [
                  // Custom hours toggle
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 14,
                          color: AppColors.textSecondary(isDark)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('Custom hours for this day',
                            style: AppType.body(context,
                                fontSize: 12,
                                color: AppColors.textSecondary(isDark))),
                      ),
                      Switch.adaptive(
                        value: hasCustom,
                        activeThumbColor: primary,
                        onChanged: (v) {
                          setState(() {
                            if (v) {
                              _expandedCustomHours.add(override.dayOfWeek);
                            } else {
                              _expandedCustomHours.remove(override.dayOfWeek);
                              // Clear custom times
                              final idx = _dayOverrides.indexWhere(
                                  (o) => o.dayOfWeek == override.dayOfWeek);
                              if (idx != -1) {
                                _dayOverrides[idx] = override.copyWith(
                                    clearCustomStart: true,
                                    clearCustomEnd: true);
                              }
                            }
                          });
                        },
                      ),
                    ],
                  ),

                  // Custom time pickers
                  if (hasCustom) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildDayTimeTile(
                          isDark: isDark,
                          label: 'Start',
                          tod: customStart,
                          color: Colors.green,
                          onTap: () => _pickTime(customStart, (t) {
                            setState(() {
                              final idx = _dayOverrides.indexWhere(
                                  (o) => o.dayOfWeek == override.dayOfWeek);
                              if (idx != -1) {
                                _dayOverrides[idx] = _dayOverrides[idx].copyWith(
                                    customStartTime: _formatTod(t));
                              }
                            });
                          }),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: _buildDayTimeTile(
                          isDark: isDark,
                          label: 'End',
                          tod: customEnd,
                          color: Colors.red,
                          onTap: () => _pickTime(customEnd, (t) {
                            setState(() {
                              final idx = _dayOverrides.indexWhere(
                                  (o) => o.dayOfWeek == override.dayOfWeek);
                              if (idx != -1) {
                                _dayOverrides[idx] = _dayOverrides[idx].copyWith(
                                    customEndTime: _formatTod(t));
                              }
                            });
                          }),
                        )),
                      ],
                    ),
                  ],

                  const SizedBox(height: 8),
                  // Label / note field
                  TextField(
                    controller: _labelControllers[override.dayOfWeek],
                    style: const TextStyle(fontSize: 12.5),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Note (e.g. Sports Day, Assembly Day)',
                      hintStyle: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(isDark)),
                      prefixIcon: Icon(Icons.label_outline_rounded,
                          size: 16,
                          color: AppColors.textSecondary(isDark)),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.smR,
                        borderSide: BorderSide(
                            color: AppColors.border(isDark), width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppRadius.smR,
                        borderSide: BorderSide(
                            color: AppColors.border(isDark), width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppRadius.smR,
                        borderSide: BorderSide(color: primary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Non-working day: just show label field
            const Divider(height: 1, indent: 14, endIndent: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: TextField(
                controller: _labelControllers[override.dayOfWeek],
                style: const TextStyle(fontSize: 12.5),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Reason (e.g. Weekend, Public Holiday)',
                  hintStyle: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(isDark)),
                  prefixIcon: Icon(Icons.label_outline_rounded,
                      size: 16,
                      color: AppColors.textSecondary(isDark)),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.smR,
                    borderSide:
                        BorderSide(color: AppColors.border(isDark), width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.smR,
                    borderSide:
                        BorderSide(color: AppColors.border(isDark), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.smR,
                    borderSide: BorderSide(color: primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDayTimeTile({
    required bool isDark,
    required String label,
    required TimeOfDay tod,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: AppRadius.smR,
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.2),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: color)),
                  Text(_todDisplay(tod),
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Time tile (tappable) ──────────────────────────────────────────────────

  Widget _buildTimeTile({
    required bool isDark,
    required String label,
    required TimeOfDay tod,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: AppRadius.mdR,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: AppRadius.mdR,
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.7),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 14, color: color),
                const SizedBox(width: 6),
                Text(
                  _todDisplay(tod),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Tap to change',
              style: TextStyle(fontSize: 10, color: AppColors.textTertiary(isDark)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Duration field ────────────────────────────────────────────────────────

  Widget _buildDurationField({
    required bool isDark,
    required String label,
    required TextEditingController controller,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : AppColors.slate100,
        borderRadius: AppRadius.mdR,
        border: Border.all(color: AppColors.border(isDark), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.textSecondary(isDark), letterSpacing: 0.7),
          ),
          Row(
            children: [
              Icon(Icons.timer_rounded, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}), // refresh timeline preview
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                                   color: AppColors.textPrimary(isDark)),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              Text('min', style: TextStyle(fontSize: 11, color: AppColors.textSecondary(isDark))),
            ],
          ),
        ],
      ),
    );
  }
}

class OrganizationInfoScreen extends StatefulWidget {
  final Organization organization;
  const OrganizationInfoScreen({super.key, required this.organization});

  @override
  State<OrganizationInfoScreen> createState() => _OrganizationInfoScreenState();
}

class _OrganizationInfoScreenState extends State<OrganizationInfoScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double>   _fadeIn;
  bool _codeCopied = false;
  late Organization _currentOrg;

  @override
  void initState() {
    super.initState();
    _currentOrg = widget.organization;
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _showEditDialog() {
    final nameController = TextEditingController(text: _currentOrg.name);
    final addressController = TextEditingController(text: _currentOrg.address ?? '');
    final countryController = TextEditingController(text: _currentOrg.country ?? '');
    
    // Sanitize and map type to avoid DropdownButton assertion crash on custom values (e.g. 'university')
    final String currentType = _currentOrg.type.trim().toLowerCase();
    String selectedType = 'organization';
    if (const ['school', 'college', 'business', 'organization'].contains(currentType)) {
      selectedType = currentType;
    } else if (currentType == 'university') {
      selectedType = 'college';
    }
    
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isSavingLocal = false;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Organisation Info'),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.xlR),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.business)),
                        validator: (v) => v == null || v.isEmpty ? 'Enter name' : null,
                        enabled: !isSavingLocal,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedType,
                        decoration: const InputDecoration(labelText: 'Type', prefixIcon: Icon(Icons.category)),
                        items: const [
                          DropdownMenuItem(value: 'school', child: Text('School')),
                          DropdownMenuItem(value: 'college', child: Text('College / University')),
                          DropdownMenuItem(value: 'business', child: Text('Business')),
                          DropdownMenuItem(value: 'organization', child: Text('Organisation')),
                        ],
                        onChanged: isSavingLocal ? null : (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedType = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: addressController,
                        decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.location_on)),
                        enabled: !isSavingLocal,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: countryController,
                        decoration: const InputDecoration(labelText: 'Country', prefixIcon: Icon(Icons.flag)),
                        enabled: !isSavingLocal,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSavingLocal ? null : () => Navigator.pop(dialogContext), 
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSavingLocal ? null : () async {
                    if (formKey.currentState!.validate()) {
                      setDialogState(() {
                        isSavingLocal = true;
                      });
                      
                      final newName = nameController.text.trim();
                      final newAddress = addressController.text.trim();
                      final newCountry = countryController.text.trim();
                      
                      try {
                        await OrganizationRepository().updateOrganizationDetails(
                          _currentOrg.id!, 
                          name: newName,
                          address: newAddress,
                          country: newCountry,
                          type: selectedType,
                        );
                        
                        if (mounted) {
                          setState(() {
                            _currentOrg = Organization(
                              id: _currentOrg.id,
                              name: newName,
                              code: _currentOrg.code,
                              type: selectedType,
                              address: newAddress,
                              country: newCountry,
                            );
                          });
                          if (!dialogContext.mounted || !context.mounted) return;
                          Navigator.pop(dialogContext); // Close dialog safely
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Organisation info updated!'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          isSavingLocal = false;
                        });
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Update failed: $e'),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: isSavingLocal
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  IconData _typeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'school':       return Icons.school_rounded;
      case 'college':      return Icons.account_balance_rounded;
      case 'business':     return Icons.business_rounded;
      case 'organization': return Icons.corporate_fare_rounded;
      default:             return Icons.domain_rounded;
    }
  }

  Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'school':       return Colors.blue;
      case 'college':      return Colors.indigo;
      case 'business':     return Colors.teal;
      case 'organization': return Colors.purple;
      default:             return Colors.blueGrey;
    }
  }

  String _typeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'school':       return 'School';
      case 'college':      return 'College / University';
      case 'business':     return 'Business';
      case 'organization': return 'Organisation';
      default:             return type;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final isDark  = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final org     = _currentOrg;
    final tColor  = _typeColor(org.type);

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeIn,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [AppColors.slate900, AppColors.slate800]
                  : [AppColors.slate50, const Color(0xFFEEF2F6)],
            ),
          ),
          child: CustomScrollView(
            slivers: [
              // ── Gradient hero app bar ─────────────────────────────────────
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                foregroundColor: Colors.white,
                backgroundColor: primary,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit_note_rounded),
                    tooltip: 'Edit Profile',
                    onPressed: _showEditDialog,
                  ),
                  const SizedBox(width: 8),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      SvgPicture.asset(
                        'assets/images/banner.svg',
                        fit: BoxFit.cover,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.35),
                              Colors.black.withValues(alpha: 0.0),
                              Colors.black.withValues(alpha: 0.6),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Org avatar + name
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                                    ),
                                    child: Icon(_typeIcon(org.type), color: Colors.white, size: 30),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          org.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            height: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.18),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                          ),
                                          child: Text(
                                            _typeLabel(org.type).toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

            // ── Body ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Join Code card (most prominent) ───────────────────
                    _buildCodeCard(isDark, tColor),
                    const SizedBox(height: AppSpace.lg),

                    // ── Details section heading ────────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 10),
                      child: Text(
                        'ORGANISATION DETAILS',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary(isDark),
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),

                    // ── Info cards ────────────────────────────────────────
                    _buildInfoCard(
                      isDark: isDark,
                      icon: Icons.location_on_rounded,
                      color: Colors.redAccent,
                      label: 'Business Address',
                      value: org.address ?? 'Not specified',
                    ),
                    const SizedBox(height: AppSpace.sm),
                    _buildInfoCard(
                      isDark: isDark,
                      icon: Icons.flag_rounded,
                      color: Colors.green,
                      label: 'Country',
                      value: org.country ?? 'Not specified',
                    ),
                    const SizedBox(height: AppSpace.sm),
                    _buildInfoCard(
                      isDark: isDark,
                      icon: _typeIcon(org.type),
                      color: tColor,
                      label: 'Organisation Type',
                      value: _typeLabel(org.type),
                    ),
                    const SizedBox(height: AppSpace.xxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  // ── Join code card ────────────────────────────────────────────────────────

  Widget _buildCodeCard(bool isDark, Color tColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tColor.withValues(alpha: isDark ? 0.25 : 0.08),
            tColor.withValues(alpha: isDark ? 0.12 : 0.03),
          ],
        ),
        borderRadius: AppRadius.lgR,
        border: Border.all(color: tColor.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tColor.withValues(alpha: 0.12),
                    borderRadius: AppRadius.mdR,
                  ),
                  child: Icon(Icons.vpn_key_rounded, size: 18, color: tColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'JOIN CODE',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: tColor,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        'Share this code with staff and students to join',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary(isDark)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            // Code display
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate800 : Colors.white,
                borderRadius: AppRadius.mdR,
                border: Border.all(color: AppColors.border(isDark)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Spaced code characters
                  ..._currentOrg.code.split('').asMap().entries.map((e) {
                    final isGroup = e.key > 0 && e.key % 3 == 0;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isGroup) Container(width: 1, height: 22, color: AppColors.border(isDark), margin: const EdgeInsets.symmetric(horizontal: 6)),
                        Text(
                          e.value,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary(isDark),
                            letterSpacing: 2,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.md),
            // Copy button
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _codeCopied
                  ? Container(
                      key: const ValueKey('copied'),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: AppRadius.mdR,
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                          SizedBox(width: 8),
                          Text('Copied to clipboard!',
                               style: TextStyle(color: Colors.green, fontWeight: FontWeight.w700, fontSize: 14)),
                        ],
                      ),
                    )
                  : InkWell(
                      key: const ValueKey('copy'),
                      borderRadius: AppRadius.mdR,
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: widget.organization.code));
                        setState(() => _codeCopied = true);
                        await Future.delayed(const Duration(seconds: 2));
                        if (mounted) setState(() => _codeCopied = false);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: tColor,
                          borderRadius: AppRadius.mdR,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.copy_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text('Copy Join Code',
                                 style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Info card row ─────────────────────────────────────────────────────────

  Widget _buildInfoCard({
    required bool isDark,
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: AppRadius.mdR,
        border: Border.all(color: AppColors.border(isDark)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: AppRadius.smR,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary(isDark),
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
