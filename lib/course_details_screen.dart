import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'course.dart';
import 'venue.dart' hide LatLng;
import 'venue_repository.dart';
import 'course_repository.dart';
import 'set_timetable_screen.dart';
import 'manage_students_screen.dart';
import 'venue_editor_screen.dart';
import 'edit_course_screen.dart';
import 'historical_report_screen.dart';
import 'timetable_repository.dart';
import 'ui/design_tokens.dart';

class CourseDetailsScreen extends StatefulWidget {
  final Course course;
  const CourseDetailsScreen({super.key, required this.course});

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen> {
  final _venueRepo = VenueRepository();
  final _courseRepo = CourseRepository();
  final _timetableRepo = TimetableRepository();
  late Future<Venue?> _venueFuture;
  late Course _currentCourse;
  bool _hasTimetable = false;

  @override
  void initState() {
    super.initState();
    _currentCourse = widget.course;
    _loadVenue();
    _checkTimetableStatus();
  }

  Future<void> _checkTimetableStatus() async {
    try {
      final slots = await _timetableRepo.getTimetableForCourse(_currentCourse.id!);
      if (mounted) {
        setState(() {
          _hasTimetable = slots.isNotEmpty;
        });
      }
    } catch (e) {
      print('⚠️ Error checking timetable status: $e');
    }
  }

  void _loadVenue() {
    if (_currentCourse.venueId != null) {
      _venueFuture = _venueRepo.getVenueById(_currentCourse.venueId!);
    } else {
      _venueFuture = Future.value(null);
    }
  }

  void _navigateToEdit() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => EditCourseScreen(course: _currentCourse),
      ),
    );

    if (result == true && mounted) {
      final updatedCourse = await _courseRepo.getCourseById(_currentCourse.id!);
      if (updatedCourse != null) {
        setState(() {
          _currentCourse = updatedCourse;
          _loadVenue();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentCourse.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, size: 28),
            onPressed: _navigateToEdit,
            tooltip: 'Edit Course',
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
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl, vertical: AppSpace.xxl),
          children: [
            // Course Header Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.xl),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpace.md),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: AppRadius.mdR,
                        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.15), width: 1),
                      ),
                      child: Icon(Icons.school_rounded, color: theme.colorScheme.primary, size: 28),
                    ),
                    const SizedBox(width: AppSpace.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SCHOOL / INSTITUTION',
                            style: AppType.body(
                              context,
                              fontSize: 11,
                              color: AppColors.textSecondary(isDark),
                              weight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _currentCourse.schoolName ?? 'Not specified',
                            style: AppType.display(
                              context,
                              fontSize: 17,
                              weight: FontWeight.w600,
                              color: AppColors.textPrimary(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpace.xxl),

            // Venue Map Preview Card Header
            Row(
              children: [
                Icon(Icons.spatial_tracking_rounded, size: 20, color: theme.colorScheme.secondary),
                const SizedBox(width: AppSpace.sm),
                Text(
                  'Volumetric venue boundaries',
                  style: AppType.display(
                    context,
                    fontSize: 17,
                    weight: FontWeight.w600,
                    color: AppColors.textPrimary(isDark),
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md - 2),

            // Map Preview Card
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: _buildVenueMap(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpace.xxxl - 4),

            // Section Title
            Row(
              children: [
                Icon(Icons.tune_rounded, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpace.sm),
                Text(
                  'Course settings & management',
                  style: AppType.display(
                    context,
                    fontSize: 17,
                    weight: FontWeight.w600,
                    color: AppColors.textPrimary(isDark),
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),

            _buildManagementTile(
              context,
              title: 'Manage students',
              subtitle: 'Add students and view registration codes',
              icon: Icons.people_outline_rounded,
              color: theme.colorScheme.primary,
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) =>
                      ManageStudentsScreen(course: _currentCourse),
                ));
              },
            ),
            const SizedBox(height: AppSpace.md - 2),

            _buildManagementTile(
              context,
              title: _hasTimetable ? 'Adjust weekly timetable' : 'Set weekly timetable',
              subtitle: 'Define the recurring class schedule',
              icon: Icons.calendar_month_outlined,
              color: AppColors.amber,
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) =>
                      SetTimetableScreen(course: _currentCourse),
                ));
                _checkTimetableStatus();
              },
            ),
            const SizedBox(height: AppSpace.md - 2),

            _buildManagementTile(
              context,
              title: 'Manage classrooms (3D geofence)',
              subtitle: 'Configure volumetric zones and height ceilings',
              icon: Icons.map_outlined,
              color: AppColors.success,
              onTap: () async {
                final currentVenue = await _venueFuture;
                if (!mounted) return;
                
                final savedVenue = await Navigator.of(context).push<Venue>(
                  MaterialPageRoute(
                    builder: (context) => VenueEditorScreen(venue: currentVenue),
                  ),
                );

                if (savedVenue != null && mounted) {
                  if (_currentCourse.venueId != savedVenue.id) {
                    final updatedCourse = Course(
                      id: _currentCourse.id,
                      teacherId: _currentCourse.teacherId,
                      name: _currentCourse.name,
                      schoolName: _currentCourse.schoolName,
                      startDate: _currentCourse.startDate,
                      endDate: _currentCourse.endDate,
                      venueId: savedVenue.id,
                    );
                    await _courseRepo.updateCourse(updatedCourse);
                    if (mounted) {
                      setState(() {
                        _currentCourse = updatedCourse;
                        _loadVenue();
                      });
                    }
                  } else {
                    if (mounted) {
                      setState(() {
                        _loadVenue();
                      });
                    }
                  }
                }
              },
            ),
            const SizedBox(height: AppSpace.md),
            const Divider(),
            const SizedBox(height: AppSpace.md),

            _buildManagementTile(
              context,
              title: 'Historical report & sync',
              subtitle: 'View attendance records and sync sheets',
              icon: Icons.bar_chart_outlined,
              color: const Color(0xFFEC4899),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) =>
                      HistoricalReportScreen(course: _currentCourse),
                ));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgR,
        side: BorderSide(color: AppColors.border(isDark), width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.xl - 2, vertical: AppSpace.sm + 2),
        leading: Container(
          padding: const EdgeInsets.all(AppSpace.md),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: AppRadius.mdR,
            border: Border.all(color: color.withOpacity(0.15), width: 1),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: AppType.display(
            context,
            fontSize: 15.5,
            weight: FontWeight.w600,
            color: AppColors.textPrimary(isDark),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppType.body(context, fontSize: 12.5, color: AppColors.textSecondary(isDark)),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.04) : AppColors.slate100,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: color),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildVenueMap(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<Venue?>(
      future: _venueFuture,
      builder: (context, snapshot) {
        if (_currentCourse.venueId == null) {
          return Container(
            color: AppColors.slate400.withOpacity(0.06),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off_rounded, color: AppColors.slate400, size: 36),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    'No geofenced venue set for this course',
                    style: AppType.body(context, color: AppColors.slate500, weight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return Container(
            color: AppColors.slate400.withOpacity(0.06),
            child: Center(
              child: Text('Venue details not found', style: AppType.body(context, color: AppColors.slate500)),
            ),
          );
        }

        final venue = snapshot.data!;
        final center = LatLng(venue.latitude, venue.longitude);

        // Draw polygon if corners exist, fallback to circular radius otherwise
        final bool showPolygon = venue.hasPolygon;

        return GoogleMap(
          initialCameraPosition: CameraPosition(target: center, zoom: 17.5),
          markers: {
            Marker(
              markerId: MarkerId(venue.id.toString()),
              position: center,
              infoWindow: InfoWindow(title: venue.name),
            )
          },
          circles: showPolygon
              ? {}
              : {
                  Circle(
                    circleId: CircleId(venue.id.toString()),
                    center: center,
                    radius: venue.radius,
                    fillColor: theme.colorScheme.primary.withOpacity(0.12),
                    strokeColor: theme.colorScheme.primary,
                    strokeWidth: 2,
                  )
                },
          polygons: showPolygon
              ? {
                  Polygon(
                    polygonId: PolygonId(venue.id.toString()),
                    points: venue.polygonCorners!
                        .map((c) => LatLng(c.latitude, c.longitude))
                        .toList(),
                    fillColor: theme.colorScheme.primary.withOpacity(0.12),
                    strokeColor: theme.colorScheme.primary,
                    strokeWidth: 2,
                  )
                }
              : {},
          scrollGesturesEnabled: false,
          zoomGesturesEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
        );
      },
    );
  }
}
