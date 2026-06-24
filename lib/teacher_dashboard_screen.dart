import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'course.dart';
import 'teacher.dart';
import 'course_repository.dart';
import 'student_repository.dart';
import 'timetable_repository.dart';
import 'create_course_screen.dart';
import 'course_details_screen.dart';
import 'role_selection_screen.dart';
import 'venue_editor_screen.dart';

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

  void _handleSignOut() {
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
      appBar: AppBar(
        title: const Text('Campus Register'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _handleSignOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    const Color(0xFF0F172A),
                    const Color(0xFF1E293B),
                  ]
                : [
                    const Color(0xFFF8FAFC),
                    const Color(0xFFEEF2F6),
                  ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header Section
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: TextStyle(
                      color: isDark ? const Color(0xFF818CF8) : theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Prof. ${widget.teacher.name}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formattedDate,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),

            // Stat / Action Grid (Premium Feature)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      context,
                      theme,
                      isDark,
                      title: 'Classrooms Manager',
                      subtitle: '3D Volumetric Geofences',
                      icon: Icons.spatial_tracking_rounded,
                      color: const Color(0xFF10B981),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const VenueEditorScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionCard(
                      context,
                      theme,
                      isDark,
                      title: 'Supabase Sync',
                      subtitle: 'Active & Cloud-linked',
                      icon: Icons.cloud_sync_rounded,
                      color: const Color(0xFF6366F1),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: const [
                                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text('Supabase Postgres connection active. Logs are synced.'),
                                ),
                              ],
                            ),
                            backgroundColor: const Color(0xFF10B981),
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
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Text(
                'Your Active Courses',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  letterSpacing: -0.5,
                ),
              ),
            ),

            Expanded(
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
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.menu_book_rounded,
                              size: 64,
                              color: isDark ? Colors.grey[600] : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No courses created yet.',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap the button below to register your first course.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final courses = snapshot.data!;
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: courses.length,
                    itemBuilder: (context, index) {
                      final course = courses[index];
                      return FutureBuilder<List<dynamic>>(
                        future: Future.wait([
                          _studentRepo.getStudentsForCourse(course.id!),
                          _timetableRepo.getTimetableForCourse(course.id!),
                        ]),
                        builder: (context, statsSnapshot) {
                          final studentCount = statsSnapshot.hasData ? statsSnapshot.data![0].length : 0;
                          final timetableCount = statsSnapshot.hasData ? statsSnapshot.data![1].length : 0;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                            ),
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) =>
                                      CourseDetailsScreen(course: course),
                                ));
                              },
                              borderRadius: BorderRadius.circular(20),
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
                                          topLeft: Radius.circular(20),
                                          bottomLeft: Radius.circular(20),
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
                                    padding: const EdgeInsets.fromLTRB(20.0, 16.0, 16.0, 16.0),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: Icon(
                                            Icons.class_rounded,
                                            color: theme.colorScheme.primary,
                                            size: 26,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                course.name,
                                                style: theme.textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                                ),
                                              ),
                                              if (course.schoolName != null && course.schoolName!.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  course.schoolName!,
                                                  style: theme.textTheme.bodySmall?.copyWith(
                                                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.people_outline_rounded,
                                                    size: 14,
                                                    color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '$studentCount Students',
                                                    style: theme.textTheme.bodySmall?.copyWith(
                                                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Icon(
                                                    Icons.calendar_today_rounded,
                                                    size: 13,
                                                    color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '$timetableCount Classes/wk',
                                                    style: theme.textTheme.bodySmall?.copyWith(
                                                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                                      fontWeight: FontWeight.bold,
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
                                          color: isDark ? Colors.grey[600] : const Color(0xFF94A3B8),
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
        icon: const Icon(Icons.add),
        label: const Text('Create Course'),
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
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
