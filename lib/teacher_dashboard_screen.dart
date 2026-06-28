import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'location_service.dart';
import 'services/biometric_service.dart';

import 'course.dart';
import 'teacher.dart';
import 'clock_log.dart';
import 'timetable_constraints.dart';
import 'course_repository.dart';
import 'student_repository.dart';
import 'timetable_repository.dart';
import 'timetable_constraints_repository.dart';
import 'clock_log_repository.dart';
import 'teacher_repository.dart';
import 'database_helper.dart';
import 'create_course_screen.dart';
import 'course_details_screen.dart';
import 'role_selection_screen.dart';
import 'manage_venues_screen.dart';
import 'venue_editor_screen.dart';
import 'venue.dart' as app_models;
import 'venue_repository.dart';
import 'about_screen.dart';
import 'settings_screen.dart';
import 'ui/design_tokens.dart';

/// The main screen for a logged-in teacher.
class TeacherDashboardScreen extends StatefulWidget {
  final Teacher teacher;

  const TeacherDashboardScreen({super.key, required this.teacher});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  final _courseRepo = CourseRepository();
  final _studentRepo = StudentRepository();
  final _timetableRepo = TimetableRepository();
  final _clockLogRepo = ClockLogRepository();
  final _teacherRepo = TeacherRepository();
  late Future<List<Course>> _coursesFuture;
  Teacher? _currentTeacher;

  ClockLog? _activeOfficeLog;
  TimetableConstraints? _constraints;

  @override
  void initState() {
    super.initState();
    _currentTeacher = widget.teacher;
    _loadCourses();
    _loadClockLogs();
  }

  void _loadClockLogs() async {
    try {
      final refreshedTeacher = await _teacherRepo.getTeacherByEmail(widget.teacher.email);
      if (mounted) {
        setState(() {
          _currentTeacher = refreshedTeacher;
        });
        // Reload courses with the potentially updated teacher ID
        _loadCourses();
      }
    } catch (_) {}

    final active = await _clockLogRepo.getActiveLog(teacherId: _currentTeacher?.id ?? widget.teacher.id, type: 'office');
    TimetableConstraints? constraints;
    if (_currentTeacher?.organizationId != null || widget.teacher.organizationId != null) {
      constraints = await TimetableConstraintsRepository().getConstraints(_currentTeacher?.organizationId ?? widget.teacher.organizationId!);
    }
    if (mounted) {
      setState(() {
        _activeOfficeLog = active;
        _constraints = constraints;
      });
    }
  }

  void _loadCourses() async {
    final teacherId = _currentTeacher?.id ?? widget.teacher.id;
    
    // Safety check: initialize with an empty future if no ID is found
    if (teacherId == null) {
      setState(() {
        _coursesFuture = Future.value([]);
      });
      return;
    }
    
    // Initialize immediately to prevent LateInitializationError during the first build
    final initialFuture = _courseRepo.getCoursesForTeacher(teacherId);
    setState(() {
      _coursesFuture = initialFuture;
    });
    
    // Safety sync: Before fetching courses, let's ensure we are using the cloud ID if available
    // and that local courses are updated to match it.
    try {
      final db = await DatabaseHelper.instance.database;
      final refreshed = await _teacherRepo.getTeacherByEmail(widget.teacher.email);
      if (refreshed.id != null && refreshed.id != teacherId) {
         print('🔄 Dashboard: Migrating courses to Cloud ID ${refreshed.id}');
         // Perform a local migration if IDs don't match
         await db.update('courses', {'teacher_id': refreshed.id}, where: 'teacher_id = ?', whereArgs: [teacherId]);
         if (mounted) {
           setState(() {
             _currentTeacher = refreshed;
             _coursesFuture = _courseRepo.getCoursesForTeacher(refreshed.id!);
           });
         }
      }
    } catch (e) {
      print('⚠️ Dashboard sync error: $e');
    }
  }

  void _navigateToCreateCourse() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateCourseScreen(teacher: _currentTeacher ?? widget.teacher),
      ),
    );
    _loadCourses();
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

    // Get time-based greeting
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'GOOD MORNING 🌤️';
    } else if (hour < 18) {
      greeting = 'GOOD AFTERNOON ☕';
    } else {
      greeting = 'GOOD EVENING 🌙';
    }

    final formattedDate = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return Scaffold(
      drawer: _buildDrawer(context),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadClockLogs();
          _loadCourses();
          await Future.delayed(const Duration(milliseconds: 500));
        },
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
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 180.0,
                pinned: true,
                backgroundColor: isDark ? AppColors.slate950 : theme.colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 4,
                title: Text(
                  'Campus Register',
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
                              Colors.black.withOpacity(0.35),
                              Colors.black.withOpacity(0.0),
                              Colors.black.withOpacity(0.6),
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
                                color: Colors.white.withOpacity(0.85),
                                weight: FontWeight.w700,
                                fontSize: 10,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Prof. ${_currentTeacher?.name ?? widget.teacher.name}',
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
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stat / Action Grid (Premium Feature)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl, vertical: AppSpace.md),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildActionCard(
                              context,
                              theme,
                              isDark,
                              title: 'Create new course',
                              subtitle: 'Setup curriculum & schedules',
                              icon: Icons.add_box_rounded,
                              color: AppColors.success,
                              onTap: () {
                                _navigateToCreateCourse();
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpace.md),
                          Expanded(
                            child: _buildActionCard(
                              context,
                              theme,
                              isDark,
                              title: 'Supabase sync',
                              subtitle: 'Active & cloud-linked',
                              icon: Icons.cloud_sync_rounded,
                              color: AppColors.indigo,
                              onTap: () async {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(Icons.sync, color: Colors.white, size: 18),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text('Synchronizing courses with cloud...'),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: AppColors.indigo,
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                                _loadCourses();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    _buildOfficeClockingCard(context, theme, isDark),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl, vertical: AppSpace.lg),
                      child: Text(
                        'Your active courses',
                        style: AppType.display(
                          context,
                          fontSize: 19,
                          weight: FontWeight.w600,
                          color: AppColors.textPrimary(isDark),
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SliverToBoxAdapter(
                child: FutureBuilder<List<Course>>(
                  future: _coursesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    } else if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 48),
                              const SizedBox(height: 16),
                              Text('Failed to load courses', style: AppType.display(context, fontSize: 16, weight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Text('${snapshot.error}', textAlign: TextAlign.center, style: AppType.body(context, fontSize: 12)),
                              TextButton(onPressed: _loadCourses, child: const Text('Try Again')),
                            ],
                          ),
                        ),
                      );
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpace.xxxl),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Lottie.asset(
                                'assets/lottie/Educatin.json',
                                height: 180,
                                width: 180,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => Icon(
                                  Icons.school_rounded,
                                  size: 80,
                                  color: theme.colorScheme.primary.withOpacity(0.1),
                                ),
                              ),
                              const SizedBox(height: AppSpace.xl),
                              Text(
                                'No courses created yet',
                                style: AppType.display(
                                  context,
                                  fontSize: 17,
                                  weight: FontWeight.w600,
                                  color: AppColors.textPrimary(isDark),
                                ),
                              ),
                              const SizedBox(height: AppSpace.sm),
                              Text(
                                'Tap the button below to register your first course.',
                                textAlign: TextAlign.center,
                                style: AppType.body(context, fontSize: 13, color: AppColors.textSecondary(isDark)),
                              ),
                              const SizedBox(height: AppSpace.lg),
                              ElevatedButton.icon(
                                onPressed: _loadCourses,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Sync with Cloud'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                                  foregroundColor: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final courses = snapshot.data!;
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: courses.length,
                      itemBuilder: (context, index) {
                        final course = courses[index];
                        if (course.id == null) return const SizedBox.shrink();

                        return FutureBuilder<List<dynamic>>(
                          future: Future.wait([
                            _studentRepo.getStudentsForCourse(course.id!),
                            _timetableRepo.getTimetableForCourse(course.id!),
                            course.venueId != null
                                ? VenueRepository().getVenueById(course.venueId!)
                                : Future.value(null),
                          ]),
                          builder: (context, statsSnapshot) {
                            final studentCount = statsSnapshot.hasData ? statsSnapshot.data![0].length : 0;
                            final timetableCount = statsSnapshot.hasData ? statsSnapshot.data![1].length : 0;
                            final app_models.Venue? venue = statsSnapshot.hasData ? statsSnapshot.data![2] as app_models.Venue? : null;

                            return Card(
                              margin: const EdgeInsets.only(bottom: AppSpace.md),
                              clipBehavior: Clip.antiAlias,
                              shape: RoundedRectangleBorder(
                                borderRadius: AppRadius.xlR,
                                side: BorderSide(color: AppColors.border(isDark), width: 1),
                              ),
                              child: InkWell(
                                onTap: () async {
                                  await Navigator.of(context).push(MaterialPageRoute(
                                    builder: (context) =>
                                        CourseDetailsScreen(course: course),
                                  ));
                                  _loadCourses();
                                },
                                borderRadius: AppRadius.xlR,
                                child: Stack(
                                  children: [
                                    // Gradient left marker border
                                    Positioned(
                                      left: 0,
                                      top: 0,
                                      bottom: 0,
                                      width: 6,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(AppRadius.xl),
                                            bottomLeft: Radius.circular(AppRadius.xl),
                                          ),
                                          gradient: LinearGradient(
                                            colors: [
                                              theme.colorScheme.primary,
                                              theme.colorScheme.secondary,
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.lg, AppSpace.lg, AppSpace.lg),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(AppSpace.md),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primary.withOpacity(0.08),
                                              borderRadius: AppRadius.mdR,
                                            ),
                                            child: Icon(
                                              Icons.class_rounded,
                                              color: theme.colorScheme.primary,
                                              size: 26,
                                            ),
                                          ),
                                          const SizedBox(width: AppSpace.lg),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  course.name,
                                                  style: AppType.display(
                                                    context,
                                                    fontSize: 16,
                                                    weight: FontWeight.w600,
                                                    color: AppColors.textPrimary(isDark),
                                                  ),
                                                ),
                                                if (course.schoolName != null && course.schoolName!.isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    course.schoolName!,
                                                    style: AppType.body(
                                                      context,
                                                      fontSize: 12,
                                                      color: AppColors.textSecondary(isDark),
                                                      weight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                                if (venue != null) ...[
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.location_on_rounded,
                                                        size: 13,
                                                        color: theme.colorScheme.primary,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                        child: Text(
                                                          venue.name,
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: AppType.body(
                                                            context,
                                                            fontSize: 12,
                                                            color: theme.colorScheme.primary,
                                                            weight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                                const SizedBox(height: AppSpace.sm),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.people_outline_rounded,
                                                      size: 14,
                                                      color: AppColors.textTertiary(isDark),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '$studentCount students',
                                                      style: AppType.data(
                                                        context,
                                                        fontSize: 11,
                                                        color: AppColors.textSecondary(isDark),
                                                        weight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    const SizedBox(width: AppSpace.md),
                                                    Icon(
                                                      Icons.calendar_today_rounded,
                                                      size: 13,
                                                      color: AppColors.textTertiary(isDark),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '$timetableCount classes/wk',
                                                      style: AppType.data(
                                                        context,
                                                        fontSize: 11,
                                                        color: AppColors.textSecondary(isDark),
                                                        weight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            size: 14,
                                            color: AppColors.textTertiary(isDark),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 100.0),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreateCourse,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create course'),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    ThemeData theme,
    bool isDark, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgR,
        side: BorderSide(color: AppColors.border(isDark), width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgR,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: AppRadius.smR,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: AppSpace.md),
              Text(
                title,
                style: AppType.display(
                  context,
                  fontSize: 13.5,
                  weight: FontWeight.w600,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppType.body(context, fontSize: 10.5, color: AppColors.textSecondary(isDark)),
              ),
            ],
          ),
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
          // Premium Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(AppSpace.xl, 60.0, AppSpace.xl, AppSpace.xl),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [AppColors.slate950, AppColors.slate900]
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
                        color: theme.colorScheme.primary.withOpacity(0.15),
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
                    color: theme.colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: theme.colorScheme.primary.withOpacity(0.15), width: 1),
                  ),
                  child: Text(
                    'FACULTY PORTAL',
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
          // Navigation List Items
          _buildDrawerItem(
            context,
            icon: Icons.dashboard_rounded,
            title: 'Courses dashboard',
            theme: theme,
            isDark: isDark,
            isActive: true,
            onTap: () {
              Navigator.of(context).pop();
            },
          ),
          _buildDrawerItem(
            context,
            icon: Icons.create_new_folder_rounded,
            title: 'Create course',
            theme: theme,
            isDark: isDark,
            isActive: false,
            indent: 16.0,
            onTap: () {
              Navigator.of(context).pop();
              _navigateToCreateCourse();
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
            icon: Icons.info_outline_rounded,
            title: 'About Campus Register',
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
            color: AppColors.dangerDark,
            onTap: () {
              Navigator.of(context).pop();
              _handleSignOut();
            },
          ),
          const SizedBox(height: AppSpace.lg),
          // Classy Footer Signature
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.xl),
            child: Column(
              children: [
                Text(
                  'CAMPUS REGISTER',
                  style: AppType.body(
                    context,
                    fontSize: 9.5,
                    weight: FontWeight.w800,
                    color: AppColors.textTertiary(isDark),
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'v1.3.0 • Secure Volumetric Geofence',
                  style: AppType.body(
                    context,
                    fontSize: 9,
                    weight: FontWeight.w500,
                    color: AppColors.textTertiary(isDark),
                  ),
                ),
              ],
            ),
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
    Color? color,
    double indent = 0.0,
    required VoidCallback onTap,
  }) {
    final activeColor = color ?? theme.colorScheme.primary;
    final defaultColor = AppColors.textSecondary(isDark);

    return Padding(
      padding: EdgeInsets.only(
        left: (AppSpace.md + 2) + indent,
        right: AppSpace.md + 2,
        top: 3.0,
        bottom: 3.0,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdR,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdR,
            color: isActive
                ? activeColor.withOpacity(isDark ? 0.12 : 0.06)
                : Colors.transparent,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 12.0),
          child: Row(
            children: [
              // Vertically Centered Left Indicator Bar
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 3.5,
                height: 18,
                decoration: BoxDecoration(
                  color: isActive ? activeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                icon,
                color: isActive ? activeColor : defaultColor,
                size: indent > 0 ? 18.0 : 20.0,
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Text(
                  title,
                  style: AppType.body(
                    context,
                    weight: isActive ? FontWeight.w700 : FontWeight.w600,
                    color: isActive ? activeColor : AppColors.textPrimary(isDark),
                    fontSize: indent > 0 ? 13.5 : 14.5,
                  ),
                ),
              ),
              if (isActive)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 10,
                  color: activeColor,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfficeClockingCard(BuildContext context, ThemeData theme, bool isDark) {
    final hasActiveLog = _activeOfficeLog != null;
    final clockInTimeStr = hasActiveLog
        ? DateFormat.jm().format(DateTime.parse(_activeOfficeLog!.clockIn))
        : '';
    final officeVenueId = _currentTeacher?.officeVenueId;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.xl, vertical: AppSpace.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasActiveLog ? Icons.work_rounded : Icons.work_outline_rounded,
                  color: hasActiveLog ? AppColors.success : AppColors.slate500,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Daily Office Attendance',
                  style: AppType.display(context, fontSize: 16, weight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              hasActiveLog
                  ? 'Clocked in to office since $clockInTimeStr.'
                  : 'You have not checked in to the office today.',
              style: TextStyle(color: AppColors.textSecondary(isDark), fontSize: 13.5),
            ),
            if (!hasActiveLog) ...[
              const SizedBox(height: 6),
              FutureBuilder<app_models.Venue?>(
                future: officeVenueId != null
                    ? VenueRepository().getVenueById(officeVenueId)
                    : Future.value(null),
                builder: (context, snapshot) {
                  final venueName = snapshot.data?.name;
                  return Text(
                    venueName != null
                        ? 'Allocated Office: $venueName'
                        : 'Office Venue: None allocated. (Clock in disabled)',
                    style: AppType.body(
                      context,
                      fontSize: 12,
                      color: venueName != null ? AppColors.indigo : Colors.red,
                      weight: FontWeight.w600,
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: AppSpace.md),
            SizedBox(
              width: double.maxFinite,
              child: ElevatedButton.icon(
                icon: Icon(hasActiveLog ? Icons.logout_rounded : Icons.login_rounded),
                label: Text(hasActiveLog ? 'Clock Out of Office' : 'Clock In to Office'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasActiveLog ? Colors.red[600] : (officeVenueId == null ? Colors.grey : theme.colorScheme.primary),
                  foregroundColor: Colors.white,
                ),
                onPressed: officeVenueId == null && !hasActiveLog
                    ? null
                    : () async {
                        if (hasActiveLog) {
                          bool isEarly = false;
                          String? shiftEndTime = _constraints?.endTime;
                          if (shiftEndTime != null) {
                            final now = TimeOfDay.now();
                            final parts = shiftEndTime.split(':');
                            final limitH = int.parse(parts[0]);
                            final limitM = int.parse(parts[1]);
                            if (now.hour < limitH || (now.hour == limitH && now.minute < limitM)) {
                              isEarly = true;
                            }
                          }

                          String? reason;
                          if (isEarly) {
                            final reasonController = TextEditingController();
                            final formKey = GlobalKey<FormState>();
                            reason = await showDialog<String>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Early Leave Waiver Request'),
                                content: Form(
                                  key: formKey,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('You are clocking out before the scheduled shift end time. Please provide a reason to request a waiver from the Admin.'),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: reasonController,
                                        decoration: const InputDecoration(labelText: 'Reason (e.g. medical appointment)'),
                                        validator: (v) => v == null || v.isEmpty ? 'Please enter a reason' : null,
                                      ),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                                  ElevatedButton(
                                    onPressed: () {
                                      if (formKey.currentState!.validate()) {
                                        Navigator.of(context).pop(reasonController.text.trim());
                                      }
                                    },
                                    child: const Text('Submit'),
                                  ),
                                ],
                              ),
                            );
                            if (reason == null) return;
                          }

                          await _clockLogRepo.clockOut(_activeOfficeLog!.id!, earlyLeaveReason: reason);
                        } else {
                          // Show loading spinner
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const Center(child: CircularProgressIndicator()),
                          );

                          // 1. Device ID verification
                          if (widget.teacher.role != 'admin') {
                            String? currentDeviceId;
                            try {
                              final deviceInfo = DeviceInfoPlugin();
                              if (Platform.isAndroid) {
                                final androidInfo = await deviceInfo.androidInfo;
                                currentDeviceId = androidInfo.id;
                              } else if (Platform.isIOS) {
                                final iosInfo = await deviceInfo.iosInfo;
                                currentDeviceId = iosInfo.identifierForVendor;
                              }
                            } catch (_) {}

                            if (currentDeviceId != null && widget.teacher.deviceAppId != null && widget.teacher.deviceAppId != currentDeviceId) {
                              if (context.mounted) {
                                Navigator.of(context).pop(); // dismiss loading
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Device Mismatch'),
                                    content: const Text('You cannot clock in from this device. Please use your registered mobile device.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
                                    ],
                                  ),
                                );
                              }
                              return;
                            }
                          }

                          // 2. Geofence presence check for the allocated office venue
                          bool insideAllocatedOffice = false;
                          app_models.Venue? allocatedVenue;
                          try {
                            final locationService = LocationService();
                            final position = await locationService.getCurrentPositionWithPermissions();
                            if (officeVenueId != null) {
                              allocatedVenue = await VenueRepository().getVenueById(officeVenueId);
                              if (allocatedVenue != null) {
                                if (allocatedVenue.hasPolygon) {
                                  insideAllocatedOffice = locationService.isPointInPolygon(
                                    position.latitude,
                                    position.longitude,
                                    allocatedVenue.polygonCorners!,
                                  );
                                } else {
                                  // fallback to radius check if no polygon corners
                                  final distance = Geolocator.distanceBetween(
                                    position.latitude,
                                    position.longitude,
                                    allocatedVenue.latitude,
                                    allocatedVenue.longitude,
                                  );
                                  insideAllocatedOffice = distance <= allocatedVenue.radius;
                                }
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              Navigator.of(context).pop(); // dismiss loading
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Location Error'),
                                  content: Text('Failed to verify location: $e'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
                                  ],
                                ),
                              );
                            }
                            return;
                          }

                          if (context.mounted) {
                            Navigator.of(context).pop(); // dismiss loading
                          }

                          if (!insideAllocatedOffice) {
                            if (context.mounted) {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Geofence Verification Failed'),
                                  content: Text(
                                    allocatedVenue != null
                                        ? 'You must be physically present inside your allocated office venue ("${allocatedVenue.name}") to clock in.'
                                        : 'No allocated office venue found. Please contact your Admin.',
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
                                  ],
                                ),
                              );
                            }
                            return;
                          }

                          // 3. Biometric fingerprint check
                          final biometricService = BiometricService();
                          final isAuthenticated = await biometricService.authenticate();
                          if (!isAuthenticated) {
                            if (context.mounted) {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Authentication Failed'),
                                  content: Text(biometricService.lastError ?? 'Biometric verification is required to clock in.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
                                  ],
                                ),
                              );
                            }
                            return;
                          }

                          await _clockLogRepo.clockIn(
                            teacherId: widget.teacher.id,
                            venueId: officeVenueId,
                            type: 'office',
                          );
                        }
                        _loadClockLogs();
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
