import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  late Future<List<StudentAttendanceView>> _attendanceFuture;
  late Future<List<TimetableSlot>> _timetableFuture;
  Course? _course;
  TimetableSlot? _activeSlot;
  Timer? _timer;
  Timer? _countdownTimer;
  String _timeLeftString = '';
  bool _isCheckingIn = false;
  bool _showGuide = false; // Toggle for volumetric tracking info guide

  @override
  void initState() {
    super.initState();
    _loadAttendance();
    _loadCourse();
    _loadTimetable();
    _startActiveSlotChecker();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _loadCourse() async {
    final course = await _courseRepo.getCourseById(widget.student.courseId);
    if (mounted) {
      setState(() {
        _course = course;
      });
    }
  }

  void _loadTimetable() {
    setState(() {
      _timetableFuture = TimetableRepository().getTimetableForCourse(widget.student.courseId);
    });
  }

  void _startActiveSlotChecker() {
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkForActiveSlot();
    });
    _checkForActiveSlot();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTimeLeft();
    });
    _updateTimeLeft();
  }

  void _updateTimeLeft() {
    if (_activeSlot == null) {
      if (_timeLeftString.isNotEmpty) {
        setState(() {
          _timeLeftString = '';
        });
      }
      return;
    }

    try {
      final now = DateTime.now();
      final timeParts = _activeSlot!.endTime.split(':');
      final endHour = int.parse(timeParts[0]);
      final endMinute = int.parse(timeParts[1]);

      final classEndTime = DateTime(now.year, now.month, now.day, endHour, endMinute);
      final difference = classEndTime.difference(now);

      if (difference.isNegative) {
        setState(() {
          _activeSlot = null;
          _timeLeftString = '';
        });
        _checkForActiveSlot();
      } else {
        final hours = difference.inHours;
        final minutes = difference.inMinutes.remainder(60);
        final seconds = difference.inSeconds.remainder(60);

        String timeStr = '';
        if (hours > 0) {
          timeStr += '${hours}h ';
        }
        timeStr += '${minutes}m ${seconds}s';

        setState(() {
          _timeLeftString = timeStr;
        });
      }
    } catch (e) {
      setState(() {
        _timeLeftString = '';
      });
    }
  }

  Future<void> _checkForActiveSlot() async {
    TimetableSlot? potentialSlot =
        await _checkInService.getActiveSlot(widget.student.courseId);

    if (potentialSlot != null) {
      final bool alreadyCheckedIn = await _checkInRepo.hasCheckedInToday(
          widget.student.id!, potentialSlot.id!);
      if (alreadyCheckedIn) {
        potentialSlot = null;
      }
    }

    if (mounted) {
      setState(() {
        _activeSlot = potentialSlot;
      });
      if (potentialSlot != null) {
        _startCountdown();
      } else {
        _countdownTimer?.cancel();
        setState(() {
          _timeLeftString = '';
        });
      }
    }
  }

  Future<void> _performCheckIn() async {
    if (_activeSlot == null) return;
    setState(() => _isCheckingIn = true);

    try {
      // --- 1. Class Time Validation ---
      final currentActiveSlot = await _checkInService.getActiveSlot(widget.student.courseId);
      if (currentActiveSlot == null || currentActiveSlot.id != _activeSlot!.id) {
        throw 'Class is not currently active. Sign-in is restricted to the specific times of that class.';
      }

      // --- 2. Location Validation & Volumetric Check ---
      final position = await _locationService.getCurrentPositionWithPermissions();

      final course = await _courseRepo.getCourseById(widget.student.courseId);
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

          if (currentAlt < venue.altitude - 2.0) {
            throw 'Underground sign-in detected. Sign-in is denied below ground level.';
          }

          if (currentAlt > venue.altitude + 5.0) {
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

      final timeParts = _activeSlot!.startTime.split(':');
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
        studentId: widget.student.id!,
        timetableSlotId: _activeSlot!.id!,
        type: 'CHECK-IN',
        timestamp: now,
        status: attendanceStatus,
        location: '${position.latitude}, ${position.longitude}',
        altitude: currentAlt,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      await _checkInRepo.createAttendanceRecord(record);

      _courseRepo.getCourseById(widget.student.courseId).then((course) {
        if (course != null) {
          _sheetsSyncService.syncRecord(
              record: record, student: widget.student, course: course);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Check-in successful!'),
            backgroundColor: Colors.green),
      );

      _loadAttendance();
      setState(() => _activeSlot = null);
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

  void _loadAttendance() {
    setState(() {
      _attendanceFuture =
          _attendanceRepo.getAttendanceForStudent(widget.student.id!);
    });
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

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('Welcome, ${widget.student.name}'),
            Text(
              'Student Portal',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
            // Active session card / scanning mode
            if (_activeSlot != null) _buildPremiumCheckInCard(theme, isDark),

            // Enrolled Course Timetable (New Feature)
            _buildTimetableSection(theme, isDark),

            // User Info Guide (Fulfills the 'provide info' request)
            _buildVolumetricGuideCard(theme, isDark),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Text(
                'Your Attendance History',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  letterSpacing: -0.6,
                ),
              ),
            ),

            Expanded(
              child: FutureBuilder<List<StudentAttendanceView>>(
                future: _attendanceFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history_rounded,
                              size: 64,
                              color: isDark ? Colors.grey[600] : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No attendance history yet.',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final records = snapshot.data!;
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      final record = records[index];
                      final day = [
                        'Mon',
                        'Tue',
                        'Wed',
                        'Thu',
                        'Fri',
                        'Sat',
                        'Sun'
                      ][record.dayOfWeek - 1];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.menu_book_rounded,
                                  color: theme.colorScheme.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      record.courseName,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${DateFormat.yMMMd().format(record.timestamp)} ($day)',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                      ),
                                    ),
                                    Text(
                                      'Session: ${record.startTime} - ${record.endTime}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildStatusBadge(record.status),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumCheckInCard(ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
              : [const Color(0xFFE0F2FE), const Color(0xFFEEF2F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xFF0EA5E9).withOpacity(isDark ? 0.4 : 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0EA5E9).withOpacity(0.12),
            blurRadius: 20,
            spreadRadius: 2,
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Pulse circle scanner animation indicator
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF0EA5E9).withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF0EA5E9).withOpacity(0.12),
                    child: const Icon(
                      Icons.fingerprint_rounded,
                      color: Color(0xFF0EA5E9),
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'LIVE CLASS IN PROGRESS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _course?.name ?? 'Enrolled Course',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: isDark ? Colors.white24 : const Color(0xFFE2E8F0)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Remaining Time',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _timeLeftString.isNotEmpty ? _timeLeftString : 'Calculating...',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                _isCheckingIn
                    ? const CircularProgressIndicator(color: Color(0xFF0EA5E9))
                    : ElevatedButton.icon(
                        onPressed: _performCheckIn,
                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                        label: const Text('Scan & Check In'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0EA5E9),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                          shadowColor: const Color(0xFF0EA5E9).withOpacity(0.4),
                        ),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimetableSection(ThemeData theme, bool isDark) {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Row(
            children: [
              Icon(Icons.calendar_month_rounded, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Weekly Timetable',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 110,
          child: FutureBuilder<List<TimetableSlot>>(
            future: _timetableFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 2)));
              }
              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B).withOpacity(0.3) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'No timetable set for this course.',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }

              final slots = snapshot.data!;
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: slots.length,
                itemBuilder: (context, index) {
                  final slot = slots[index];
                  final dayName = days[slot.dayOfWeek - 1];
                  final today = DateTime.now().weekday;
                  final isToday = slot.dayOfWeek == today;

                  return Container(
                    width: 160,
                    margin: const EdgeInsets.only(right: 12, bottom: 8, top: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: isToday
                          ? LinearGradient(
                              colors: isDark
                                  ? [theme.colorScheme.primary.withOpacity(0.25), const Color(0xFF1E293B)]
                                  : [theme.colorScheme.primary.withOpacity(0.15), Colors.white],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isToday ? null : (isDark ? const Color(0xFF1E293B) : Colors.white),
                      border: Border.all(
                        color: isToday
                            ? theme.colorScheme.primary.withOpacity(0.5)
                            : (isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0)),
                        width: isToday ? 1.5 : 1,
                      ),
                      boxShadow: isToday
                          ? [
                              BoxShadow(
                                color: theme.colorScheme.primary.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                dayName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isToday
                                      ? (isDark ? Colors.white : theme.colorScheme.primary)
                                      : (isDark ? Colors.white : const Color(0xFF1E293B)),
                                ),
                              ),
                              if (isToday)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Today',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 13,
                                color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${slot.startTime} - ${slot.endTime}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVolumetricGuideCard(ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        color: isDark ? const Color(0xFF1E293B).withOpacity(0.3) : Colors.white.withOpacity(0.5),
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
          leading: Icon(
            Icons.info_outline_rounded,
            color: theme.colorScheme.primary,
          ),
          title: Text(
            'How Volumetric Check-In Works',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  _buildGuideBullet(
                    Icons.pin_drop_rounded,
                    '3D Geofencing',
                    'Your device must be within the coordinates defining the classroom area.',
                    isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildGuideBullet(
                    Icons.layers_rounded,
                    'Altitude Matching',
                    'Check-ins are rejected on other floors or below ground level.',
                    isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildGuideBullet(
                    Icons.fingerprint_rounded,
                    'Biometric Lock',
                    'Verifies physical attendance identity at the moment of registration.',
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

  Widget _buildGuideBullet(IconData icon, String title, String desc, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF818CF8)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;
    
    switch (status.toUpperCase()) {
      case 'PRESENT':
        color = const Color(0xFF10B981); // Emerald Green
        icon = Icons.check_circle_rounded;
        break;
      case 'LATE':
        color = const Color(0xFFF59E0B); // Amber
        icon = Icons.schedule_rounded;
        break;
      case 'ABSENT':
        color = const Color(0xFFEF4444); // Rose Red
        icon = Icons.cancel_rounded;
        break;
      default:
        color = const Color(0xFF6B7280); // Grey
        icon = Icons.help_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
