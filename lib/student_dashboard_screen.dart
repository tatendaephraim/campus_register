import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';

import 'attendance_record.dart';
import 'student.dart';
import 'course.dart';
import 'timetable.dart';
import 'timetable_repository.dart';
import 'location_service.dart';
import 'google_sheets_sync_service.dart';
import 'venue_repository.dart';
import 'course_repository.dart';
import 'check_in_repository.dart';
import 'services/biometric_service.dart';
import 'services/altitude_service.dart';
import 'check_in_service.dart';
import 'attendance_repository.dart';
import 'student_attendance_view.dart';
import 'role_selection_screen.dart';
import 'student_repository.dart';
import 'student_registration_screen.dart';
import 'student_course_details_screen.dart';
import 'ui/design_tokens.dart';

class StudentDashboardScreen extends StatefulWidget {
  final Student student;
  const StudentDashboardScreen({super.key, required this.student});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  final _attendanceRepo = AttendanceRepository();
  final _checkInService = CheckInService();
  final _checkInRepo = CheckInRepository();
  final _biometricService = BiometricService();
  final _sheetsSyncService = GoogleSheetsSyncService();
  final _courseRepo = CourseRepository();
  final _locationService = LocationService();
  final _venueRepo = VenueRepository();

  Timer? _timer;
  Timer? _countdownTimer;
  bool _isCheckingIn = false;
  bool _showGuide = false; // Toggle for volumetric tracking info guide

  List<Student> _studentProfiles = [];
  late Student _currentStudent;

  // Multi-course states
  final Map<int, List<StudentAttendanceView>> _attendanceByProfileId = {};
  final Map<int, List<TimetableSlot>> _timetableByProfileId = {};
  final Map<int, Course> _courseByProfileId = {};
  final Map<int, TimetableSlot?> _activeSlotByProfileId = {};
  final Map<int, int> _visibleHistoryLimitByProfileId = {};
  final Map<int, bool> _hasCheckedInByProfileId = {};
  final Map<int, bool> _isInsideVenueByProfileId = {};
  bool _isLoadingDashboard = true;

  @override
  void initState() {
    super.initState();
    _currentStudent = widget.student;
    _loadAllDashboardData();
    _startActiveSlotChecker();
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startActiveSlotChecker() {
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkAllActiveSlots();
    });
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {}); // Trigger rebuild to update time left labels dynamically
      }
    });
  }

  Future<void> _checkAllActiveSlots() async {
    // 1. Gather active slots first (very fast DB queries)
    bool hasAnyActiveSlot = false;
    final Map<int, TimetableSlot?> slots = {};
    final Map<int, bool> checkedIn = {};

    for (var profile in _studentProfiles) {
      final profileId = profile.id!;
      final TimetableSlot? potentialSlot = await _checkInService.getActiveSlot(profile.courseId);
      slots[profileId] = potentialSlot;
      if (potentialSlot != null) {
        hasAnyActiveSlot = true;
        checkedIn[profileId] = await _checkInRepo.hasCheckedInToday(profileId, potentialSlot.id!);
      }
    }

    // 2. Only request location if there is actually a live session!
    Position? position;
    if (hasAnyActiveSlot) {
      try {
        // Try getting last known position first (instantaneous)
        position = await Geolocator.getLastKnownPosition();
        // If last known position is null, get current position with a short timeout and medium accuracy
        position ??= await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 4),
        );
      } catch (_) {}
    }

    // 3. Update geofence states and UI
    for (var profile in _studentProfiles) {
      final profileId = profile.id!;
      final potentialSlot = slots[profileId];
      final alreadyCheckedIn = checkedIn[profileId] ?? false;

      bool isInsideVenue = false;
      if (potentialSlot != null && position != null) {
        final course = _courseByProfileId[profileId];
        if (course?.venueId != null) {
          final venue = await _venueRepo.getVenueById(course!.venueId!);
          if (venue != null && venue.hasPolygon) {
            isInsideVenue = _locationService.isPointInPolygon(
              position.latitude,
              position.longitude,
              venue.polygonCorners!,
            );
          }
        }
      }

      if (mounted) {
        setState(() {
          _activeSlotByProfileId[profileId] = potentialSlot;
          _hasCheckedInByProfileId[profileId] = alreadyCheckedIn;
          _isInsideVenueByProfileId[profileId] = isInsideVenue;
        });
      }
    }
  }

  Future<void> _loadAllDashboardData() async {
    if (mounted) {
      setState(() {
        _isLoadingDashboard = true;
      });
    }

    try {
      final profiles = await StudentRepository().getStudentsByDeviceId(_currentStudent.deviceAppId);
      _studentProfiles = profiles;
      
      _attendanceByProfileId.clear();
      _timetableByProfileId.clear();
      _courseByProfileId.clear();
      _activeSlotByProfileId.clear();

      // Load all profiles in parallel to speed up database queries
      await Future.wait(_studentProfiles.map((profile) async {
        final profileId = profile.id!;
        
        // Fetch course, attendance, timetable, and active slot concurrently
        final results = await Future.wait([
          _courseRepo.getCourseById(profile.courseId),
          _attendanceRepo.getAttendanceForStudent(profileId),
          TimetableRepository().getTimetableForCourse(profile.courseId),
          _checkInService.getActiveSlot(profile.courseId),
        ]);

        final course = results[0] as Course?;
        final attendance = results[1] as List<StudentAttendanceView>;
        final timetable = results[2] as List<TimetableSlot>;
        final potentialSlot = results[3] as TimetableSlot?;

        if (course != null) {
          _courseByProfileId[profileId] = course;
        }

        _attendanceByProfileId[profileId] = attendance;
        _timetableByProfileId[profileId] = timetable;
        _activeSlotByProfileId[profileId] = potentialSlot;
        
        bool alreadyCheckedIn = false;
        if (potentialSlot != null) {
          alreadyCheckedIn = await _checkInRepo.hasCheckedInToday(profileId, potentialSlot.id!);
        }
        _hasCheckedInByProfileId[profileId] = alreadyCheckedIn;
        _isInsideVenueByProfileId[profileId] = false;
        
        _visibleHistoryLimitByProfileId.putIfAbsent(profileId, () => 3);

        // Run backfill absent records in the background (no need to await it to show UI!)
        _checkInRepo.backfillAbsentRecords(profile.courseId).catchError((_) => 0);
      }));
      
      // Run location check asynchronously
      _checkAllActiveSlots();
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDashboard = false;
        });
      }
    }
  }

  Future<void> _performCheckIn(Student student, TimetableSlot activeSlot) async {
    setState(() => _isCheckingIn = true);

    try {
      // --- 1. Class Time Validation ---
      final currentActiveSlot = await _checkInService.getActiveSlot(student.courseId);
      if (currentActiveSlot == null || currentActiveSlot.id != activeSlot.id) {
        throw 'Class is not currently active. Sign-in is restricted to the specific times of that class.';
      }

      // --- 2. Location Validation & Volumetric Check ---
      final position = await _locationService.getCurrentPositionWithPermissions();

      final course = _courseByProfileId[student.id!];
      if (course?.venueId != null) {
        final venue = await _venueRepo.getVenueById(course!.venueId!);
        if (venue != null) {
          if (!venue.hasPolygon) {
            throw 'Class geofence is invalid. Must have at least 3 corners defined.';
          }

          final isInsidePolygon = _locationService.isPointInPolygon(
            position.latitude,
            position.longitude,
            venue.polygonCorners!,
          );
          if (!isInsidePolygon) {
            throw 'You are not inside the classroom. Sign-in is restricted to the 3D class boundary.';
          }

          final currentAlt = AltitudeService.instance.getCombinedAltitude(position.altitude);

          final double toleranceLower = 8.0;
          final double toleranceUpper = venue.verticalTolerance > 0.0 ? venue.verticalTolerance : 12.0;

          if (currentAlt < venue.altitude - toleranceLower) {
            throw 'Underground sign-in detected. Sign-in is denied below ground level.';
          }

          if (currentAlt > venue.altitude + toleranceUpper) {
            throw 'Upper floor sign-in detected. Fingerprint sensor deactivated because you are not in the classroom.';
          }
        }
      } else {
        throw 'No geofenced venue is set for this course. Please contact your instructor.';
      }

      // --- 3. Biometric Authentication ---
      final isAuthenticated = await _biometricService.authenticate();
      if (!isAuthenticated) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(_biometricService.lastError ?? 'Authentication failed.'),
              backgroundColor: Colors.red),
        );
        setState(() => _isCheckingIn = false);
        return;
      }

      final now = DateTime.now();

      // --- 4. Determine Attendance Status (PRESENT or LATE) ---
      String attendanceStatus = 'PRESENT';
      const gracePeriodMinutes = 5;

      final timeParts = activeSlot.startTime.split(':');
      final startHour = int.parse(timeParts[0]);
      final startMinute = int.parse(timeParts[1]);

      final classStartTime =
          DateTime(now.year, now.month, now.day, startHour, startMinute);

      if (now.isAfter(
          classStartTime.add(const Duration(minutes: gracePeriodMinutes)))) {
        attendanceStatus = 'LATE';
      }

      final currentAlt = AltitudeService.instance.getCombinedAltitude(position.altitude);

      final record = AttendanceRecord(
        studentId: student.id!,
        timetableSlotId: activeSlot.id!,
        type: 'CHECK-IN',
        timestamp: now,
        status: attendanceStatus,
        location: '${position.latitude}, ${position.longitude}',
        altitude: currentAlt,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      await _checkInRepo.createAttendanceRecord(record);

      _sheetsSyncService.syncRecord(
          record: record, student: student, course: course);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Check-in successful!'),
            backgroundColor: Colors.green),
      );

      _loadAllDashboardData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Check-in failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isCheckingIn = false);
    }
  }

  void _handleSignOut() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
      (route) => false,
    );
  }

  void _showStudentProfileDialog() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.account_circle_rounded, size: 28, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpace.sm),
              Text('Student profile', style: AppType.display(context, fontSize: 17, weight: FontWeight.w600)),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.xlR),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NAME',
                style: AppType.body(context, weight: FontWeight.w700, color: AppColors.textSecondary(isDark), fontSize: 11, letterSpacing: 0.4),
              ),
              Text(
                _currentStudent.name,
                style: AppType.display(context, weight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: AppSpace.md),
              Text(
                'BOUND DEVICE ID',
                style: AppType.body(context, weight: FontWeight.w700, color: AppColors.textSecondary(isDark), fontSize: 11, letterSpacing: 0.4),
              ),
              SelectableText(
                _currentStudent.deviceAppId,
                style: AppType.data(context, fontSize: 13),
              ),
              const SizedBox(height: AppSpace.md),
              Text(
                'ENROLLED COURSES',
                style: AppType.body(context, weight: FontWeight.w700, color: AppColors.textSecondary(isDark), fontSize: 11, letterSpacing: 0.4),
              ),
              const SizedBox(height: 4),
              ..._studentProfiles.map((profile) {
                final course = _courseByProfileId[profile.id!];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    course?.name ?? 'Loading…',
                    style: AppType.display(context, fontSize: 13.5, weight: FontWeight.w600),
                  ),
                );
              }),
              const SizedBox(height: AppSpace.xl),
              const Divider(),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Reset Device Binding'),
                        content: const Text(
                          'Warning: This will delete all course enrollments registered to this device. You will need a new invitation code to sign in again.\n\nDo you want to proceed?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.danger,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Reset binding'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await StudentRepository().deleteStudent(_currentStudent.id!);
                      if (context.mounted) {
                        Navigator.of(context).pop(); // dismiss profile dialog
                        _handleSignOut();
                      }
                    }
                  },
                  icon: const Icon(Icons.phonelink_erase_rounded, size: 16),
                  label: const Text('Reset Device Binding'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.smR),
                  ),
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
        );
      },
    );
  }

  String _getRemainingTime(TimetableSlot slot) {
    try {
      final now = DateTime.now();
      final timeParts = slot.endTime.split(':');
      final endHour = int.parse(timeParts[0]);
      final endMinute = int.parse(timeParts[1]);

      final classEndTime = DateTime(now.year, now.month, now.day, endHour, endMinute);
      final difference = classEndTime.difference(now);

      if (difference.isNegative) {
        return 'Ended';
      } else {
        final hours = difference.inHours;
        final minutes = difference.inMinutes.remainder(60);
        final seconds = difference.inSeconds.remainder(60);

        String timeStr = '';
        if (hours > 0) {
          timeStr += '${hours}h ';
        }
        timeStr += '${minutes}m ${seconds}s';
        return timeStr;
      }
    } catch (_) {
      return 'Calculating…';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
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
                'Student Portal',
                style: AppType.display(context, fontSize: 18, weight: FontWeight.w700, color: Colors.white),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  tooltip: 'Register New Course',
                  onPressed: () async {
                    final result = await Navigator.of(context).push<Student>(
                      MaterialPageRoute(builder: (context) => const StudentRegistrationScreen()),
                    );
                    if (result != null) {
                      _loadAllDashboardData();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded),
                  onPressed: _handleSignOut,
                  tooltip: 'Sign Out',
                ),
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
                            'STUDENT PORTAL',
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
                            _currentStudent.name,
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
                            'Dashboard Feed',
                            style: AppType.body(
                              context,
                              fontSize: 12.5,
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

            if (_isLoadingDashboard)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_studentProfiles.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.xxl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Lottie.asset(
                          'assets/lottie/register.json',
                          height: 180,
                          width: 180,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.menu_book_rounded,
                            size: 64,
                            color: AppColors.slate400,
                          ),
                        ),
                        const SizedBox(height: AppSpace.xl),
                        Text(
                          'No courses registered yet',
                          style: AppType.display(
                            context,
                            fontSize: 17,
                            weight: FontWeight.w600,
                            color: AppColors.textPrimary(isDark),
                          ),
                        ),
                        const SizedBox(height: AppSpace.sm),
                        Text(
                          'Tap the "+" button in the header to register your first course.',
                          textAlign: TextAlign.center,
                          style: AppType.body(context, fontSize: 13, color: AppColors.textSecondary(isDark)),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildVolumetricGuideCard(theme, isDark),
                  ],
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final student = _studentProfiles[index];
                    return _buildCourseDashboardCard(context, theme, isDark, student);
                  },
                  childCount: _studentProfiles.length,
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: AppSpace.xxl),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showStudentProfileDialog,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.account_circle_rounded),
        label: const Text('View Profile'),
      ),
    );
  }

  Widget _buildCourseDashboardCard(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    Student student,
  ) {
    final course = _courseByProfileId[student.id!];
    if (course == null) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.sm),
        child: const Padding(
          padding: EdgeInsets.all(AppSpace.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final attendance = _attendanceByProfileId[student.id!] ?? [];
    final activeSlot = _activeSlotByProfileId[student.id!];

    // Calculate dynamic attendance rate for basic info
    double rate = 0.0;
    if (attendance.isNotEmpty) {
      int presentOrLate = 0;
      for (var record in attendance) {
        final status = record.status.toUpperCase();
        if (status == 'PRESENT' || status == 'LATE') {
          presentOrLate++;
        }
      }
      rate = presentOrLate / attendance.length;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.sm + 2),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.xlR,
        side: BorderSide(color: AppColors.border(isDark), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => StudentCourseDetailsScreen(
                student: student,
                course: course,
              ),
            ),
          );
          _loadAllDashboardData();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Basic Info Header
            Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                    child: Icon(Icons.class_rounded, color: theme.colorScheme.primary, size: 22),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.name,
                          style: AppType.display(context, fontSize: 16, weight: FontWeight.w700, color: AppColors.textPrimary(isDark)),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (course.schoolName != null && course.schoolName!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            course.schoolName!,
                            style: AppType.body(context, fontSize: 12, color: AppColors.textSecondary(isDark), weight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.slate400),
                ],
              ),
            ),

            // Attendance Rate Bar (Basic Info Indicator)
            Padding(
              padding: const EdgeInsets.only(left: AppSpace.lg, right: AppSpace.lg, bottom: AppSpace.lg),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Attendance Adherence',
                        style: AppType.body(context, fontSize: 11.5, color: AppColors.textSecondary(isDark), weight: FontWeight.w600),
                      ),
                      Text(
                        '${(rate * 100).toStringAsFixed(0)}%',
                        style: AppType.body(context, fontSize: 12, color: theme.colorScheme.primary, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: rate,
                      minHeight: 6,
                      backgroundColor: isDark ? AppColors.slate800 : AppColors.slate200,
                      color: rate >= 0.75
                          ? AppColors.success
                          : (rate >= 0.5 ? AppColors.warning : AppColors.danger),
                    ),
                  ),
                ],
              ),
            ),

            // Live check-in overlay card if class active (flashing border container)
            if (activeSlot != null)
              GestureDetector(
                onTap: () {}, // Prevent navigating to details screen when tapping inside the check-in overlay
                child: _buildPremiumCheckInCard(theme, isDark, student, activeSlot),
              ),
          ],
        ),
      ),
    );
  }


  Widget _buildPremiumCheckInCard(ThemeData theme, bool isDark, Student student, TimetableSlot activeSlot) {
    final timeLeft = _getRemainingTime(activeSlot);
    final hasCheckedIn = _hasCheckedInByProfileId[student.id!] ?? false;
    final isInsideVenue = _isInsideVenueByProfileId[student.id!] ?? false;

    // Define colors and styles dynamically
    Color primaryColor;
    Color secondaryColor;
    Color accentTextColor;
    String statusTitle;
    String statusSubtitle;
    IconData statusIcon;

    if (hasCheckedIn) {
      primaryColor = AppColors.success;
      secondaryColor = isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5);
      accentTextColor = isDark ? const Color(0xFF34D399) : const Color(0xFF047857);
      statusTitle = 'CHECK-IN SUCCESSFUL';
      statusSubtitle = 'Your attendance has been registered.';
      statusIcon = Icons.verified_rounded;
    } else if (isInsideVenue) {
      primaryColor = theme.colorScheme.primary;
      secondaryColor = isDark ? AppColors.indigoDeep : const Color(0xFFE0F2FE);
      accentTextColor = isDark ? theme.colorScheme.primary : const Color(0xFF0369A1);
      statusTitle = 'INSIDE CLASS BOUNDS';
      statusSubtitle = 'Biometric check-in ready.';
      statusIcon = Icons.fingerprint_rounded;
    } else {
      primaryColor = AppColors.warning;
      secondaryColor = isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7);
      accentTextColor = isDark ? AppColors.amberLight : const Color(0xFFB45309);
      statusTitle = 'OUTSIDE CLASS BOUNDS';
      statusSubtitle = 'Please move inside the classroom.';
      statusIcon = Icons.location_off_rounded;
    }

    final card = Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.xlR,
        gradient: LinearGradient(
          colors: isDark
              ? [secondaryColor, AppColors.slate900]
              : [primaryColor.withOpacity(0.12), primaryColor.withOpacity(0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: primaryColor.withOpacity(isDark ? 0.4 : 0.2),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryColor.withOpacity(0.3), width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: primaryColor.withOpacity(0.12),
                    child: Icon(statusIcon, color: primaryColor, size: 26),
                  ),
                ),
                const SizedBox(width: AppSpace.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: hasCheckedIn ? AppColors.success : (isInsideVenue ? AppColors.success : AppColors.warning),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            statusTitle,
                            style: AppType.body(
                              context,
                              fontSize: 11,
                              weight: FontWeight.w700,
                              color: accentTextColor,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        statusSubtitle,
                        style: AppType.display(
                          context,
                          fontSize: 15,
                          weight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.slate900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            Divider(height: 1, color: isDark ? Colors.white24 : AppColors.slate200),
            const SizedBox(height: AppSpace.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REMAINING TIME',
                      style: AppType.body(
                        context,
                        fontSize: 11,
                        weight: FontWeight.w600,
                        color: AppColors.textSecondary(isDark),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeLeft,
                      style: AppType.data(
                        context,
                        fontSize: 18,
                        weight: FontWeight.w600,
                        color: isDark ? AppColors.amberLight : const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
                if (hasCheckedIn)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.12),
                      borderRadius: AppRadius.smR,
                      border: Border.all(color: AppColors.success.withOpacity(0.3), width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
                        const SizedBox(width: 8),
                        Text(
                          'Checked in',
                          style: AppType.body(context, color: AppColors.success, weight: FontWeight.w700, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                else
                  _isCheckingIn
                      ? SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(color: primaryColor, strokeWidth: 3),
                        )
                      : ElevatedButton.icon(
                          onPressed: () => _performCheckIn(student, activeSlot),
                          icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                          label: const Text('Scan & check in'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: AppRadius.smR),
                            elevation: 2,
                          ),
                        ),
              ],
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: PulsingBorder(
        color: primaryColor,
        isLight: !isDark,
        borderRadius: 16.0,
        child: card,
      ),
    );
  }


  Widget _buildVolumetricGuideCard(ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.sm),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgR,
          side: BorderSide(color: AppColors.border(isDark), width: 1),
        ),
        color: isDark ? AppColors.slate800.withOpacity(0.3) : Colors.white.withOpacity(0.5),
        child: ExpansionTile(
          shape: const Border(),
          trailing: Icon(
            _showGuide ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
            color: theme.colorScheme.primary,
          ),
          onExpansionChanged: (expanded) {
            setState(() {
              _showGuide = expanded;
            });
          },
          leading: Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary),
          title: Text(
            'How volumetric check-in works',
            style: AppType.display(
              context,
              fontSize: 14,
              weight: FontWeight.w600,
              color: AppColors.textPrimary(isDark),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: AppSpace.lg, right: AppSpace.lg, bottom: AppSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  _buildGuideBullet(
                    context,
                    Icons.pin_drop_rounded,
                    'GPS geofence',
                    'Your device must sit inside the coordinates that define the classroom boundary.',
                    isDark,
                  ),
                  const SizedBox(height: AppSpace.sm + 2),
                  _buildGuideBullet(
                    context,
                    Icons.layers_rounded,
                    'Altitude window',
                    'Check-ins outside the volumetric height band (-8m to +12m) are rejected — restricting sign-ins from different floors.',
                    isDark,
                  ),
                  const SizedBox(height: AppSpace.sm + 2),
                  _buildGuideBullet(
                    context,
                    Icons.schedule_rounded,
                    'Lesson clock',
                    'Biometric check-in only unlocks once location and altitude hold and the scheduled lesson time has started.',
                    isDark,
                  ),
                  const SizedBox(height: AppSpace.sm + 2),
                  _buildGuideBullet(
                    context,
                    Icons.fingerprint_rounded,
                    'Biometric lock',
                    'Confirms it is really you, on your own enrolled device, for the whole session.',
                    isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideBullet(BuildContext context, IconData icon, String title, String desc, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppType.display(
                  context,
                  fontSize: 13,
                  weight: FontWeight.w600,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: AppType.body(context, fontSize: 12, color: AppColors.textSecondary(isDark), height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

}

class PulsingBorder extends StatefulWidget {
  final Widget child;
  final Color color;
  final double borderRadius;
  final bool isLight;

  const PulsingBorder({
    super.key,
    required this.child,
    required this.color,
    this.borderRadius = 16.0,
    required this.isLight,
  });

  @override
  State<PulsingBorder> createState() => _PulsingBorderState();
}

class _PulsingBorderState extends State<PulsingBorder> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.15, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(_animation.value * (widget.isLight ? 0.35 : 0.65)),
                blurRadius: 10 + 8 * _animation.value,
                spreadRadius: 1 + 3 * _animation.value,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
