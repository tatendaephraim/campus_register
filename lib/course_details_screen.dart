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

class CourseDetailsScreen extends StatefulWidget {
  final Course course;
  const CourseDetailsScreen({super.key, required this.course});

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen> {
  final _venueRepo = VenueRepository();
  final _courseRepo = CourseRepository();
  late Future<Venue?> _venueFuture;
  late Course _currentCourse;

  @override
  void initState() {
    super.initState();
    _currentCourse = widget.course;
    _loadVenue();
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
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          children: [
            // Course Header Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.school_rounded,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'School/Institution',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _currentCourse.schoolName ?? 'Not Specified',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Venue Map Preview Card Header
            Row(
              children: [
                Icon(Icons.spatial_tracking_rounded, size: 20, color: theme.colorScheme.secondary),
                const SizedBox(width: 8),
                Text(
                  'Volumetric Venue Boundaries',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            // Map Preview Card
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: _buildVenueMap(),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 28),
            
            // Section Title
            Row(
              children: [
                Icon(Icons.tune_rounded, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Course Settings & Management',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Management Tiles
            _buildManagementTile(
              context,
              title: 'Manage Students',
              subtitle: 'Add students and view registration codes',
              icon: Icons.people_outline_rounded,
              color: const Color(0xFF6366F1),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) =>
                      ManageStudentsScreen(course: _currentCourse),
                ));
              },
            ),
            const SizedBox(height: 10),
            
            _buildManagementTile(
              context,
              title: 'Set Weekly Timetable',
              subtitle: 'Define the recurring class schedule',
              icon: Icons.calendar_month_outlined,
              color: const Color(0xFFF59E0B),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) =>
                      SetTimetableScreen(course: _currentCourse),
                ));
              },
            ),
            const SizedBox(height: 10),
            
            _buildManagementTile(
              context,
              title: 'Manage Classrooms (3D Geofence)',
              subtitle: 'Configure volumetric zones and height ceilings',
              icon: Icons.map_outlined,
              color: const Color(0xFF10B981),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const VenueEditorScreen(),
                ));
              },
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            
            _buildManagementTile(
              context,
              title: 'Historical Report & Sync',
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[100],
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.arrow_forward_ios_rounded,
            size: 12,
            color: color,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildVenueMap() {
    return FutureBuilder<Venue?>(
      future: _venueFuture,
      builder: (context, snapshot) {
        if (_currentCourse.venueId == null) {
          return Container(
            color: Colors.grey.withOpacity(0.05),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off_rounded, color: Colors.grey, size: 36),
                  SizedBox(height: 8),
                  Text(
                    'No geofenced venue set for this course.',
                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
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
            color: Colors.grey.withOpacity(0.05),
            child: const Center(child: Text('Venue details not found.')),
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
                    fillColor: const Color(0xFF6366F1).withOpacity(0.12),
                    strokeColor: const Color(0xFF6366F1),
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
                    fillColor: const Color(0xFF6366F1).withOpacity(0.12),
                    strokeColor: const Color(0xFF6366F1),
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
