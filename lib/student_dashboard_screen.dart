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
import 'student_profile_screen.dart';
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
  final Map<int, AttendanceRecord?> _attendanceRecordsToday = {};
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
    final Map<int, AttendanceRecord?> recordsToday = {};

    for (var profile in _studentProfiles) {
      final profileId = profile.id!;
      final TimetableSlot? potentialSlot = profile.courseId != null
          ? await _checkInService.getActiveSlot(profile.courseId!)
          : null;
      slots[profileId] = potentialSlot;
      if (potentialSlot != null) {
        hasAnyActiveSlot = true;
        recordsToday[profileId] = await _checkInRepo.getAttendanceRecordToday(profileId, potentialSlot.id!);
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
      final recordToday = recordsToday[profileId];

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
          _attendanceRecordsToday[profileId] = recordToday;
          _hasCheckedInByProfileId[profileId] = recordToday != null;
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
      final rawProfiles = await StudentRepository().getStudentsByDeviceId(_currentStudent.deviceAppId);
      final List<Student> profiles = [];

      _attendanceByProfileId.clear();
      _timetableByProfileId.clear();
      _courseByProfileId.clear();
      _activeSlotByProfileId.clear();

      // Load all profiles and resolve their course assignments in parallel
      await Future.wait(rawProfiles.map((profile) async {
        final profileId = profile.id!;
        final courseId = await StudentRepository().getEnrolledCourseId(profileId);
        
        final resolvedStudent = Student(
          id: profile.id,
          courseId: courseId,
          organizationId: profile.organizationId,
          name: profile.name,
          email: profile.email,
          deviceAppId: profile.deviceAppId,
          isApproved: profile.isApproved,
        );
        profiles.add(resolvedStudent);

        // Fetch course, attendance, timetable, and active slot
        Course? course;
        List<StudentAttendanceView> attendance = [];
        List<TimetableSlot> timetable = [];
        TimetableSlot? potentialSlot;

        if (courseId != null) {
          final results = await Future.wait([
            _courseRepo.getCourseById(courseId),
            _attendanceRepo.getAttendanceForStudent(profileId),
            TimetableRepository().getTimetableForCourse(courseId),
            _checkInService.getActiveSlot(courseId),
          ]);

          course = results[0] as Course?;
          attendance = results[1] as List<StudentAttendanceView>;
          timetable = results[2] as List<TimetableSlot>;
          potentialSlot = results[3] as TimetableSlot?;
        } else {
          attendance = await _attendanceRepo.getAttendanceForStudent(profileId);
        }

        if (course != null) {
          _courseByProfileId[profileId] = course;
        }

        _attendanceByProfileId[profileId] = attendance;
        _timetableByProfileId[profileId] = timetable;
        _activeSlotByProfileId[profileId] = potentialSlot;
        
        AttendanceRecord? recordToday;
        if (potentialSlot != null) {
          recordToday = await _checkInRepo.getAttendanceRecordToday(profileId, potentialSlot.id!);
        }
        _attendanceRecordsToday[profileId] = recordToday;
        _hasCheckedInByProfileId[profileId] = recordToday != null;
        _isInsideVenueByProfileId[profileId] = false;
        
        _visibleHistoryLimitByProfileId.putIfAbsent(profileId, () => 3);

        if (courseId != null) {
          _checkInRepo.backfillAbsentRecords(courseId).catchError((_) => 0);
        }
      }));
      
      if (mounted) {
        setState(() {
          _studentProfiles = profiles;
        });
      }
      
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
      if (student.courseId == null) {
        throw 'Student is not enrolled in a course.';
      }
      final currentActiveSlot = await _checkInService.getActiveSlot(student.courseId!);
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

  bool _isCheckOutWindow(String endTimeStr) {
    try {
      final now = DateTime.now();
      final parts = endTimeStr.split(':');
      final endHour = int.parse(parts[0]);
      final endMinute = int.parse(parts[1]);
      
      final classEnd = DateTime(now.year, now.month, now.day, endHour, endMinute);
      final windowStart = classEnd.subtract(const Duration(minutes: 5));
      final windowEnd = classEnd.add(const Duration(minutes: 5));
      
      return now.isAfter(windowStart) && now.isBefore(windowEnd);
    } catch (e) {
      return false;
    }
  }

  bool _isBeforeCheckOutWindow(String endTimeStr) {
    try {
      final now = DateTime.now();
      final parts = endTimeStr.split(':');
      final endHour = int.parse(parts[0]);
      final endMinute = int.parse(parts[1]);
      
      final classEnd = DateTime(now.year, now.month, now.day, endHour, endMinute);
      final windowStart = classEnd.subtract(const Duration(minutes: 5));
      
      return now.isBefore(windowStart);
    } catch (e) {
      return false;
    }
  }

  Future<void> _performCheckOut(Student student, TimetableSlot activeSlot, AttendanceRecord record) async {
    setState(() => _isCheckingIn = true);

    try {
      if (student.courseId == null) {
        throw 'Student is not enrolled in a course.';
      }
      
      if (!_isCheckOutWindow(activeSlot.endTime)) {
        throw 'Check-out is locked. You can only check out from 5 minutes before to 5 minutes after class ends.';
      }

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
            throw 'You are not inside the classroom. Check-out is restricted to the 3D class boundary.';
          }
        }
      }

      final isAuthenticated = await _biometricService.authenticate();
      if (!isAuthenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(_biometricService.lastError ?? 'Authentication failed.'),
                backgroundColor: Colors.red),
          );
        }
        setState(() => _isCheckingIn = false);
        return;
      }

      final now = DateTime.now();
      await _checkInRepo.checkoutAttendanceRecord(record.id!, now.toIso8601String());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Check-out successful!'),
              backgroundColor: Colors.green),
        );
      }

      _loadAllDashboardData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Check-out failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingIn = false);
      }
    }
  }

  void _handleSignOut() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
      (route) => false,
    );
  }

  void _navigateToStudentProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StudentProfileScreen(
          currentStudent: _currentStudent,
          studentProfiles: _studentProfiles,
          courseByProfileId: _courseByProfileId,
          attendanceByProfileId: _attendanceByProfileId,
        ),
      ),
    );
  }

  TimetableSlot? _getNextLesson(List<TimetableSlot> slots) {
    if (slots.isEmpty) return null;
    final now = DateTime.now();
    final currentWeekday = now.weekday;

    TimetableSlot? nextSlot;
    Duration? minDiff;

    for (final slot in slots) {
      final timeParts = slot.startTime.split(':');
      if (timeParts.length != 2) continue;
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      int daysUntil = slot.dayOfWeek - currentWeekday;
      if (daysUntil < 0) {
        daysUntil += 7;
      } else if (daysUntil == 0) {
        // It's today. Check if the start time has already passed.
        final slotStartToday = DateTime(now.year, now.month, now.day, hour, minute);
        if (slotStartToday.isBefore(now)) {
          daysUntil = 7; // Next week
        }
      }

      final targetDate = now.add(Duration(days: daysUntil));
      final targetStart = DateTime(targetDate.year, targetDate.month, targetDate.day, hour, minute);
      final diff = targetStart.difference(now);

      if (minDiff == null || diff < minDiff) {
        minDiff = diff;
        nextSlot = slot;
      }
    }

    return nextSlot;
  }

  String _getTimeRemainingToNext(TimetableSlot slot) {
    try {
      final now = DateTime.now();
      final currentWeekday = now.weekday;
      
      final timeParts = slot.startTime.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      int daysUntil = slot.dayOfWeek - currentWeekday;
      if (daysUntil < 0) {
        daysUntil += 7;
      } else if (daysUntil == 0) {
        final slotStartToday = DateTime(now.year, now.month, now.day, hour, minute);
        if (slotStartToday.isBefore(now)) {
          daysUntil = 7;
        }
      }

      final targetDate = now.add(Duration(days: daysUntil));
      final targetStart = DateTime(targetDate.year, targetDate.month, targetDate.day, hour, minute);
      final difference = targetStart.difference(now);

      final days = difference.inDays;
      final hours = difference.inHours.remainder(24);
      final minutes = difference.inMinutes.remainder(60);

      if (days > 0) {
        return '${days}d ${hours}h remaining';
      } else if (hours > 0) {
        return '${hours}h ${minutes}m remaining';
      } else {
        return '${minutes}m remaining';
      }
    } catch (_) {
      return 'Calculating…';
    }
  }

  String _getDayName(int day) {
    switch (day) {
      case 1: return 'Mon';
      case 2: return 'Tue';
      case 3: return 'Wed';
      case 4: return 'Thu';
      case 5: return 'Fri';
      case 6: return 'Sat';
      case 7: return 'Sun';
      default: return '';
    }
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
                          'assets/lottie/classroom.json',
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
                child: SizedBox(height: 100.0),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToStudentProfile,
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
      if (_isLoadingDashboard) {
        return const Card(
          margin: EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.sm),
          child: Padding(
            padding: EdgeInsets.all(AppSpace.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    final attendance = _attendanceByProfileId[student.id!] ?? [];
    final activeSlot = _activeSlotByProfileId[student.id!];
    final slots = _timetableByProfileId[student.id!] ?? [];
    final nextLesson = _getNextLesson(slots);

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

            if (nextLesson != null) ...[
              Padding(
                padding: const EdgeInsets.only(left: AppSpace.lg, right: AppSpace.lg, bottom: AppSpace.lg),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate900.withValues(alpha: 0.5) : AppColors.slate50,
                    borderRadius: AppRadius.smR,
                    border: Border.all(color: AppColors.border(isDark)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 15,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(
                        child: Text(
                          'Next: ${_getDayName(nextLesson.dayOfWeek)} at ${nextLesson.startTime}',
                          style: AppType.body(
                            context,
                            fontSize: 12,
                            weight: FontWeight.w600,
                            color: AppColors.textPrimary(isDark),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getTimeRemainingToNext(nextLesson),
                          style: AppType.body(
                            context,
                            fontSize: 11,
                            weight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

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
                  Builder(
                    builder: (context) {
                      final record = _attendanceRecordsToday[student.id!];
                      if (record == null) {
                        return const SizedBox.shrink();
                      }
                     if (record.checkedOutAt != null) {
                       return Container(
                         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                         decoration: BoxDecoration(
                           color: Colors.blue.withOpacity(0.12),
                           borderRadius: AppRadius.smR,
                           border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1.5),
                         ),
                         child: Row(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             const Icon(Icons.check_circle_rounded, size: 16, color: Colors.blue),
                             const SizedBox(width: 8),
                             Text(
                               'Checked out',
                               style: AppType.body(context, color: Colors.blue, weight: FontWeight.w700, fontSize: 13),
                             ),
                           ],
                         ),
                       );
                     }
                     if (_isCheckOutWindow(activeSlot.endTime)) {
                       return ElevatedButton.icon(
                         onPressed: () => _performCheckOut(student, activeSlot, record),
                         icon: const Icon(Icons.logout_rounded, size: 18),
                         label: const Text('Scan & check out'),
                         style: ElevatedButton.styleFrom(
                           backgroundColor: Colors.teal,
                           foregroundColor: Colors.white,
                           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                           shape: RoundedRectangleBorder(borderRadius: AppRadius.smR),
                           elevation: 2,
                         ),
                       );
                     }
                     if (_isBeforeCheckOutWindow(activeSlot.endTime)) {
                       return Container(
                         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                         decoration: BoxDecoration(
                           color: AppColors.success.withOpacity(0.1),
                           borderRadius: AppRadius.smR,
                         ),
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.end,
                           children: [
                             Row(
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                 const Icon(Icons.lock_clock_rounded, size: 14, color: AppColors.success),
                                 const SizedBox(width: 6),
                                 Text(
                                   'Checked In',
                                   style: AppType.body(context, color: AppColors.success, weight: FontWeight.w700, fontSize: 12),
                                 ),
                               ],
                             ),
                             const SizedBox(height: 2),
                             const Text(
                               'Check-out opens 5m before end',
                               style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w600),
                             ),
                           ],
                         ),
                       );
                     }
                     // Missed checkout window
                     return Container(
                       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                       decoration: BoxDecoration(
                         color: Colors.orange.withOpacity(0.12),
                         borderRadius: AppRadius.smR,
                         border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1.5),
                       ),
                       child: Row(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                           const SizedBox(width: 8),
                           Text(
                             'Check-out locked',
                             style: AppType.body(context, color: Colors.orange, weight: FontWeight.w700, fontSize: 13),
                           ),
                         ],
                       ),
                     );
                   },
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
