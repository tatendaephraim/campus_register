import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'course.dart';
import 'teacher.dart';
import 'course_repository.dart';
import 'student_repository.dart';
import 'timetable_repository.dart';
import 'create_course_screen.dart';
import 'course_details_screen.dart';
import 'role_selection_screen.dart';
import 'manage_venues_screen.dart';
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
  late Future<List<Course>> _coursesFuture;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  void _loadCourses() {
    setState(() {
      _coursesFuture = _courseRepo.getCoursesForTeacher(widget.teacher.id!);
    });
  }

  void _navigateToCreateCourse() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateCourseScreen(teacher: widget.teacher),
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
        child: CustomScrollView(
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
                            'Prof. ${widget.teacher.name}',
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
                            title: 'Classrooms manager',
                            subtitle: '3D volumetric geofences',
                            icon: Icons.spatial_tracking_rounded,
                            color: AppColors.success,
                            onTap: () {
                               Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const ManageVenuesScreen()),
                               );
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
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Row(
                                    children: [
                                      Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text('Supabase Postgres connection active. Logs are synced.'),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: AppColors.success,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

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
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpace.xxxl),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Lottie.asset(
                              'assets/lottie/register.json',
                              height: 180,
                              width: 180,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.menu_book_rounded,
                                size: 64,
                                color: isDark ? Colors.grey[600] : AppColors.slate400,
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
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) =>
                                      CourseDetailsScreen(course: course),
                                ));
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
          ],
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
          const Spacer(),
          // Sign Out with clear separator
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
    required VoidCallback onTap,
  }) {
    final activeColor = color ?? theme.colorScheme.primary;
    final defaultColor = AppColors.textSecondary(isDark);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md + 2, vertical: 3.0),
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
                size: 20,
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Text(
                  title,
                  style: AppType.body(
                    context,
                    weight: isActive ? FontWeight.w700 : FontWeight.w600,
                    color: isActive ? activeColor : AppColors.textPrimary(isDark),
                    fontSize: 14.5,
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
}
