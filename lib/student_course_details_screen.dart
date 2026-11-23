import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'course.dart';
import 'student.dart';
import 'venue.dart' hide LatLng;
import 'timetable.dart';
import 'student_attendance_view.dart';
import 'attendance_repository.dart';
import 'timetable_repository.dart';
import 'venue_repository.dart';
import 'check_in_repository.dart';
import 'ui/design_tokens.dart';

class StudentCourseDetailsScreen extends StatefulWidget {
  final Student student;
  final Course course;

  const StudentCourseDetailsScreen({
    super.key,
    required this.student,
    required this.course,
  });

  @override
  State<StudentCourseDetailsScreen> createState() => _StudentCourseDetailsScreenState();
}

class _StudentCourseDetailsScreenState extends State<StudentCourseDetailsScreen> {
  final _attendanceRepo = AttendanceRepository();
  final _timetableRepo = TimetableRepository();
  final _venueRepo = VenueRepository();
  final _checkInRepo = CheckInRepository();

  bool _isLoading = true;
  List<StudentAttendanceView> _attendance = [];
  List<TimetableSlot> _timetable = [];
  Venue? _venue;

  int _visibleHistoryLimit = 3;

  @override
  void initState() {
    super.initState();
    _loadCourseDetails();
  }

  Future<void> _loadCourseDetails() async {
    setState(() => _isLoading = true);

    try {
      // Run backfill absent records in the background (no need to await it to show UI!)
      _checkInRepo.backfillAbsentRecords(widget.course.id!).catchError((_) => 0);

      // Load other details in parallel to speed up loading
      final results = await Future.wait([
        _attendanceRepo.getAttendanceForStudent(widget.student.id!),
        _timetableRepo.getTimetableForCourse(widget.course.id!),
        widget.course.venueId != null
            ? _venueRepo.getVenueById(widget.course.venueId!)
            : Future.value(null),
      ]);

      if (mounted) {
        setState(() {
          _attendance = results[0] as List<StudentAttendanceView>;
          _timetable = results[1] as List<TimetableSlot>;
          _venue = results[2] as Venue?;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading course details: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  double _calculateAttendanceRate() {
    if (_attendance.isEmpty) return 0.0;
    int presentOrLate = 0;
    for (var record in _attendance) {
      final status = record.status.toUpperCase();
      if (status == 'PRESENT' || status == 'LATE') {
        presentOrLate++;
      }
    }
    return presentOrLate / _attendance.length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final rate = _calculateAttendanceRate();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course.name),
        backgroundColor: isDark ? AppColors.slate950 : theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [AppColors.slate900, AppColors.slate800]
                      : [AppColors.slate50, const Color(0xFFEEF2F6)],
                ),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Course Header Card
                      _buildCourseHeader(isDark, theme),
                      const SizedBox(height: AppSpace.md),

                      // Attendance Summary / Stats Row
                      _buildStatsSection(isDark, theme, rate),
                      const SizedBox(height: AppSpace.md),

                      // Weekly Timetable Section
                      _buildTimetableSection(isDark, theme),
                      const SizedBox(height: AppSpace.md),

                      // Venue & Geofencing Map Section
                      if (_venue != null) ...[
                        _buildVenueSection(isDark, theme),
                        const SizedBox(height: AppSpace.md),
                      ],

                      // Attendance History Logs
                      _buildAttendanceHistorySection(isDark, theme),
                      const SizedBox(height: AppSpace.xxl),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCourseHeader(bool isDark, ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgR,
        side: BorderSide(color: AppColors.border(isDark), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
              child: Icon(Icons.class_rounded, color: theme.colorScheme.primary, size: 24),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.course.name,
                    style: AppType.display(context, fontSize: 18, weight: FontWeight.w700, color: AppColors.textPrimary(isDark)),
                  ),
                  if (widget.course.schoolName != null && widget.course.schoolName!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.course.schoolName!,
                      style: AppType.body(context, fontSize: 13, color: AppColors.textSecondary(isDark), weight: FontWeight.w500),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(bool isDark, ThemeData theme, double rate) {
    int presentCount = 0;
    int lateCount = 0;
    int absentCount = 0;

    for (var record in _attendance) {
      final status = record.status.toUpperCase();
      if (status == 'PRESENT') presentCount++;
      if (status == 'LATE') lateCount++;
      if (status == 'ABSENT') absentCount++;
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgR,
        side: BorderSide(color: AppColors.border(isDark), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance statistics',
              style: AppType.display(context, fontSize: 15, weight: FontWeight.w700, color: AppColors.textPrimary(isDark)),
            ),
            const SizedBox(height: AppSpace.md),
            Row(
              children: [
                Expanded(child: _buildStatCapsule('PRESENT', presentCount, AppColors.success, isDark)),
                const SizedBox(width: AppSpace.xs),
                Expanded(child: _buildStatCapsule('LATE', lateCount, AppColors.warning, isDark)),
                const SizedBox(width: AppSpace.xs),
                Expanded(child: _buildStatCapsule('ABSENT', absentCount, AppColors.danger, isDark)),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Adherence rate',
                  style: AppType.body(context, fontSize: 13, color: AppColors.textSecondary(isDark), weight: FontWeight.w600),
                ),
                Text(
                  '${(rate * 100).toStringAsFixed(0)}%',
                  style: AppType.display(context, fontSize: 15, weight: FontWeight.w700, color: theme.colorScheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: rate,
                minHeight: 8,
                backgroundColor: isDark ? AppColors.slate800 : AppColors.slate200,
                color: rate >= 0.75
                    ? AppColors.success
                    : (rate >= 0.5 ? AppColors.warning : AppColors.danger),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCapsule(String statusLabel, int count, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: AppSpace.xs),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: AppRadius.mdR,
        border: Border.all(color: color.withOpacity(0.12), width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: AppType.display(context, fontSize: 18, weight: FontWeight.w700, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            statusLabel,
            style: AppType.body(context, fontSize: 9, weight: FontWeight.w700, color: color, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildTimetableSection(bool isDark, ThemeData theme) {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgR,
        side: BorderSide(color: AppColors.border(isDark), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month_rounded, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpace.sm),
                Text(
                  'Weekly timetable',
                  style: AppType.display(context, fontSize: 15, weight: FontWeight.w700, color: AppColors.textPrimary(isDark)),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            if (_timetable.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
                child: Text(
                  'No class schedule set yet.',
                  style: AppType.body(context, fontSize: 13, color: AppColors.textSecondary(isDark)),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _timetable.length,
                itemBuilder: (context, index) {
                  final slot = _timetable[index];
                  final isToday = slot.dayOfWeek == DateTime.now().weekday;

                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpace.sm),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.slate900.withOpacity(0.5) : AppColors.slate50,
                      borderRadius: AppRadius.mdR,
                      border: Border.all(
                        color: isToday ? theme.colorScheme.primary.withOpacity(0.4) : AppColors.border(isDark),
                        width: isToday ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 15,
                              color: isToday ? theme.colorScheme.primary : AppColors.textTertiary(isDark),
                            ),
                            const SizedBox(width: AppSpace.md),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  days[slot.dayOfWeek - 1],
                                  style: AppType.body(context, fontSize: 13, weight: FontWeight.w600, color: AppColors.textPrimary(isDark)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${slot.startTime} – ${slot.endTime}',
                                  style: AppType.data(context, fontSize: 12, color: AppColors.textSecondary(isDark)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (isToday)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.12),
                              borderRadius: AppRadius.smR,
                            ),
                            child: Text(
                              'TODAY',
                              style: AppType.body(context, fontSize: 9.5, weight: FontWeight.w800, color: theme.colorScheme.primary, letterSpacing: 0.6),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVenueSection(bool isDark, ThemeData theme) {
    if (_venue == null) return const SizedBox();
    final center = LatLng(_venue!.latitude, _venue!.longitude);
    final bool showPolygon = _venue!.hasPolygon;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgR,
        side: BorderSide(color: AppColors.border(isDark), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on_rounded, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: AppSpace.sm),
                    Text(
                      'Classroom venue details',
                      style: AppType.display(context, fontSize: 15, weight: FontWeight.w700, color: AppColors.textPrimary(isDark)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.md),
                Text(
                  _venue!.name,
                  style: AppType.body(context, fontSize: 14, weight: FontWeight.w600, color: AppColors.textPrimary(isDark)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Altitude: ${_venue!.altitude.toStringAsFixed(1)}m (Tolerance: +${_venue!.verticalTolerance > 0 ? _venue!.verticalTolerance : 12.0}m)',
                  style: AppType.body(context, fontSize: 12.5, color: AppColors.textSecondary(isDark)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 180,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: center, zoom: 17.5),
              markers: {
                Marker(
                  markerId: MarkerId(_venue!.id.toString()),
                  position: center,
                  infoWindow: InfoWindow(title: _venue!.name),
                )
              },
              circles: showPolygon
                  ? {}
                  : {
                      Circle(
                        circleId: CircleId(_venue!.id.toString()),
                        center: center,
                        radius: _venue!.radius,
                        fillColor: theme.colorScheme.primary.withOpacity(0.12),
                        strokeColor: theme.colorScheme.primary,
                        strokeWidth: 2,
                      )
                    },
              polygons: showPolygon
                  ? {
                      Polygon(
                        polygonId: PolygonId(_venue!.id.toString()),
                        points: _venue!.polygonCorners!
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
              myLocationButtonEnabled: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceHistorySection(bool isDark, ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgR,
        side: BorderSide(color: AppColors.border(isDark), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Attendance history',
                  style: AppType.display(context, fontSize: 15, weight: FontWeight.w700, color: AppColors.textPrimary(isDark)),
                ),
                Text(
                  '${_attendance.length} total',
                  style: AppType.body(context, fontSize: 12, color: AppColors.textSecondary(isDark), weight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            if (_attendance.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
                child: Center(
                  child: Text(
                    'No attendance history recorded yet.',
                    style: AppType.body(context, fontSize: 13, color: AppColors.textSecondary(isDark)),
                  ),
                ),
              )
            else ...[
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _attendance.take(_visibleHistoryLimit).length,
                itemBuilder: (context, index) {
                  final record = _attendance[index];
                  final day = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][record.dayOfWeek - 1];
                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpace.sm),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.slate900.withOpacity(0.5) : AppColors.slate50,
                      borderRadius: AppRadius.mdR,
                      border: Border.all(color: AppColors.border(isDark), width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 16,
                          color: theme.colorScheme.primary.withOpacity(0.7),
                        ),
                        const SizedBox(width: AppSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${DateFormat.yMMMd().format(record.timestamp)} ($day)',
                                style: AppType.body(context, fontSize: 12.5, color: AppColors.textPrimary(isDark), weight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Session: ${record.startTime} – ${record.endTime}',
                                style: AppType.data(context, fontSize: 11, color: AppColors.textSecondary(isDark)),
                              ),
                            ],
                          ),
                        ),
                        _buildStatusBadge(record.status),
                      ],
                    ),
                  );
                },
              ),

              // Pagination controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_attendance.length > _visibleHistoryLimit)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _visibleHistoryLimit += 5;
                        });
                      },
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text(
                        'Show more (+${_attendance.length - _visibleHistoryLimit} records)',
                        style: AppType.body(context, fontSize: 12, weight: FontWeight.w600, color: theme.colorScheme.primary),
                      ),
                    )
                  else
                    const SizedBox(),
                  if (_visibleHistoryLimit > 3)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _visibleHistoryLimit = 3;
                        });
                      },
                      child: Text(
                        'Show less',
                        style: AppType.body(context, fontSize: 12, weight: FontWeight.w600, color: AppColors.textSecondary(isDark)),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;

    switch (status.toUpperCase()) {
      case 'PRESENT':
        color = AppColors.success;
        icon = Icons.check_circle_rounded;
        break;
      case 'LATE':
        color = AppColors.warning;
        icon = Icons.schedule_rounded;
        break;
      case 'ABSENT':
        color = AppColors.danger;
        icon = Icons.cancel_rounded;
        break;
      default:
        color = AppColors.slate500;
        icon = Icons.help_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: AppRadius.smR,
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            status,
            style: AppType.body(context, color: color, weight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
