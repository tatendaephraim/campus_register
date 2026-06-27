import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'student.dart';
import 'course.dart';
import 'student_attendance_view.dart';
import 'student_repository.dart';
import 'role_selection_screen.dart';
import 'ui/design_tokens.dart';

class StudentProfileScreen extends StatefulWidget {
  final Student currentStudent;
  final List<Student> studentProfiles;
  final Map<int, Course> courseByProfileId;
  final Map<int, List<StudentAttendanceView>> attendanceByProfileId;

  const StudentProfileScreen({
    super.key,
    required this.currentStudent,
    required this.studentProfiles,
    required this.courseByProfileId,
    required this.attendanceByProfileId,
  });

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  bool _isResetting = false;

  void _handleSignOut() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
      (route) => false,
    );
  }

  Future<void> _confirmResetDeviceBinding() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 28),
            SizedBox(width: AppSpace.sm),
            Text('Reset Device Binding'),
          ],
        ),
        content: const Text(
          'Warning: This will delete all course enrollments registered to this device. '
          'You will need a new invitation code to sign in again.\n\n'
          'Do you want to proceed?',
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
      setState(() => _isResetting = true);
      try {
        await StudentRepository().deleteStudent(widget.currentStudent.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Device binding reset successfully'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _handleSignOut();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to reset binding: $e'),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isResetting = false);
        }
      }
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.currentStudent.deviceAppId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Device ID copied to clipboard'),
        backgroundColor: AppColors.indigo,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Calculate overall attendance rate across all profiles
    int totalSessions = 0;
    int attendedSessions = 0;

    for (var profile in widget.studentProfiles) {
      final attendanceList = widget.attendanceByProfileId[profile.id!] ?? [];
      totalSessions += attendanceList.length;
      for (var record in attendanceList) {
        final status = record.status.toUpperCase();
        if (status == 'PRESENT' || status == 'LATE') {
          attendedSessions++;
        }
      }
    }

    final double overallRate = totalSessions > 0 ? attendedSessions / totalSessions : 0.0;
    final initials = widget.currentStudent.name.isNotEmpty ? widget.currentStudent.name[0].toUpperCase() : 'S';

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
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 220.0,
              pinned: true,
              backgroundColor: isDark ? AppColors.slate950 : theme.colorScheme.primary,
              foregroundColor: Colors.white,
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
                            Colors.black.withValues(alpha: 0.5),
                            Colors.black.withValues(alpha: 0.2),
                            Colors.black.withValues(alpha: 0.7),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.xl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            child: CircleAvatar(
                              radius: 32,
                              backgroundColor: Colors.white,
                              foregroundColor: theme.colorScheme.primary,
                              child: Text(
                                initials,
                                style: AppType.display(
                                  context,
                                  fontSize: 26,
                                  weight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpace.sm),
                          Text(
                            widget.currentStudent.name,
                            style: AppType.display(
                              context,
                              fontSize: 18.5,
                              weight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Student Academic Profile',
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
            SliverList(
              delegate: SliverChildListDelegate([
                if (_isResetting)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpace.xxl),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  // 1. Academic Summary Card
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, 0),
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.xlR,
                        side: BorderSide(color: AppColors.border(isDark), width: 1.5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpace.lg),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ENROLLED COURSES',
                                    style: AppType.body(
                                      context,
                                      fontSize: 10,
                                      weight: FontWeight.w700,
                                      color: AppColors.textSecondary(isDark),
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${widget.studentProfiles.length}',
                                    style: AppType.display(
                                      context,
                                      fontSize: 24,
                                      weight: FontWeight.w700,
                                      color: AppColors.textPrimary(isDark),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              height: 40,
                              width: 1.5,
                              color: AppColors.border(isDark),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: AppSpace.lg),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'OVERALL ATTENDANCE',
                                      style: AppType.body(
                                        context,
                                        fontSize: 10,
                                        weight: FontWeight.w700,
                                        color: AppColors.textSecondary(isDark),
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          totalSessions > 0 ? '${(overallRate * 100).toStringAsFixed(0)}%' : 'N/A',
                                          style: AppType.display(
                                            context,
                                            fontSize: 24,
                                            weight: FontWeight.w700,
                                            color: totalSessions > 0
                                                ? (overallRate >= 0.75 ? AppColors.success : (overallRate >= 0.5 ? AppColors.warning : AppColors.danger))
                                                : AppColors.textPrimary(isDark),
                                          ),
                                        ),
                                        const SizedBox(width: AppSpace.sm),
                                        if (totalSessions > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: (overallRate >= 0.75 ? AppColors.success : (overallRate >= 0.5 ? AppColors.warning : AppColors.danger)).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '$attendedSessions / $totalSessions',
                                              style: AppType.body(
                                                context,
                                                fontSize: 10.5,
                                                weight: FontWeight.w700,
                                                color: overallRate >= 0.75 ? AppColors.success : (overallRate >= 0.5 ? AppColors.warning : AppColors.danger),
                                              ),
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
                  ),

                  // 2. Course Enrollments List Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.xl, AppSpace.xl, AppSpace.xs),
                    child: Text(
                      'COURSE ENROLLMENTS',
                      style: AppType.body(
                        context,
                        fontSize: 11,
                        weight: FontWeight.w700,
                        color: AppColors.textSecondary(isDark),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),

                  // Course cards list
                  ...widget.studentProfiles.map((profile) {
                    final course = widget.courseByProfileId[profile.id!];
                    final attendanceList = widget.attendanceByProfileId[profile.id!] ?? [];

                    int attended = 0;
                    for (var r in attendanceList) {
                      final s = r.status.toUpperCase();
                      if (s == 'PRESENT' || s == 'LATE') {
                        attended++;
                      }
                    }

                    final double rate = attendanceList.isNotEmpty ? attended / attendanceList.length : 0.0;
                    final ratePct = (rate * 100).toStringAsFixed(0);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: 4),
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.lgR,
                          side: BorderSide(color: AppColors.border(isDark), width: 1.2),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpace.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                                    child: Icon(Icons.school_rounded, color: theme.colorScheme.primary, size: 18),
                                  ),
                                  const SizedBox(width: AppSpace.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          course?.name ?? 'Loading Course...',
                                          style: AppType.display(
                                            context,
                                            fontSize: 14.5,
                                            weight: FontWeight.w700,
                                            color: AppColors.textPrimary(isDark),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (course?.schoolName != null && course!.schoolName!.isNotEmpty)
                                          Text(
                                            course.schoolName!,
                                            style: AppType.body(
                                              context,
                                              fontSize: 11.5,
                                              color: AppColors.textSecondary(isDark),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: (attendanceList.isEmpty
                                              ? AppColors.textSecondary(isDark)
                                              : (rate >= 0.75 ? AppColors.success : (rate >= 0.5 ? AppColors.warning : AppColors.danger)))
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      attendanceList.isNotEmpty ? '$ratePct%' : 'N/A',
                                      style: AppType.body(
                                        context,
                                        fontSize: 11,
                                        weight: FontWeight.w700,
                                        color: attendanceList.isEmpty
                                            ? AppColors.textSecondary(isDark)
                                            : (rate >= 0.75 ? AppColors.success : (rate >= 0.5 ? AppColors.warning : AppColors.danger)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpace.md),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Attendance details',
                                    style: AppType.body(context, fontSize: 11.5, color: AppColors.textSecondary(isDark)),
                                  ),
                                  Text(
                                    attendanceList.isNotEmpty
                                        ? '$attended of ${attendanceList.length} classes attended'
                                        : 'No sessions logged',
                                    style: AppType.body(context, fontSize: 11.5, color: AppColors.textPrimary(isDark), weight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: attendanceList.isNotEmpty ? rate : 0.0,
                                  minHeight: 5,
                                  backgroundColor: isDark ? AppColors.slate900 : AppColors.slate100,
                                  color: rate >= 0.75
                                      ? AppColors.success
                                      : (rate >= 0.5 ? AppColors.warning : AppColors.danger),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  // 3. Device & Verification Security Info Card
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xl, AppSpace.lg, 0),
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.xlR,
                        side: BorderSide(color: AppColors.border(isDark), width: 1.2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpace.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.security_rounded, color: AppColors.indigo, size: 20),
                                const SizedBox(width: AppSpace.sm),
                                Text(
                                  'DEVICE BINDING',
                                  style: AppType.body(
                                    context,
                                    fontSize: 11,
                                    weight: FontWeight.w700,
                                    color: AppColors.textPrimary(isDark),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpace.sm),
                            Text(
                              'This student account is bound to your physical device. '
                              'For security, geofencing, altitude matching, and biometrics work strictly '
                              'within the registered hardware device context.',
                              style: AppType.body(
                                context,
                                fontSize: 12,
                                color: AppColors.textSecondary(isDark),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: AppSpace.md),
                            Text(
                              'UNIQUE HARDWARE IDENTIFIER',
                              style: AppType.body(
                                context,
                                fontSize: 10,
                                weight: FontWeight.w700,
                                color: AppColors.textSecondary(isDark),
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.all(AppSpace.sm),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.slate900 : AppColors.slate50,
                                borderRadius: AppRadius.smR,
                                border: Border.all(color: AppColors.border(isDark)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: SelectableText(
                                      widget.currentStudent.deviceAppId,
                                      style: AppType.data(context, fontSize: 11.5),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _copyToClipboard,
                                    icon: const Icon(Icons.copy_all_rounded, size: 18),
                                    tooltip: 'Copy ID',
                                    color: theme.colorScheme.primary,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 4. Danger Zone Card
                  Padding(
                    padding: const EdgeInsets.all(AppSpace.lg),
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.xlR,
                        side: const BorderSide(color: AppColors.danger, width: 1.2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpace.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.warning_rounded, color: AppColors.danger, size: 20),
                                const SizedBox(width: AppSpace.sm),
                                Text(
                                  'DANGER ZONE',
                                  style: AppType.body(
                                    context,
                                    fontSize: 11,
                                    weight: FontWeight.w700,
                                    color: AppColors.danger,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpace.sm),
                            Text(
                              'Resetting the device binding deletes all local student credentials, '
                              'attendance indexes, and course memberships on this device. '
                              'You will need a new invitation from a teacher to re-register.',
                              style: AppType.body(
                                context,
                                fontSize: 12,
                                color: AppColors.textSecondary(isDark),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: AppSpace.md),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _confirmResetDeviceBinding,
                                icon: const Icon(Icons.phonelink_erase_rounded, size: 16),
                                label: const Text('Reset Device Binding'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.danger,
                                  side: const BorderSide(color: AppColors.danger, width: 1.2),
                                  shape: RoundedRectangleBorder(borderRadius: AppRadius.smR),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpace.xxl),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
