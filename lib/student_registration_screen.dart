import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'student.dart';
import 'student_repository.dart';
import 'student_dashboard_screen.dart';
import 'teacher.dart';
import 'course.dart';
import 'teacher_repository.dart';
import 'course_repository.dart';
import 'ui/design_tokens.dart';

class StudentRegistrationScreen extends StatefulWidget {
  const StudentRegistrationScreen({super.key});

  @override
  State<StudentRegistrationScreen> createState() =>
      _StudentRegistrationScreenState();
}

class _StudentRegistrationScreenState extends State<StudentRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _studentRepo = StudentRepository();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<String?> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id; // A unique ID for the Android device
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor; // A unique ID for the app vendor
    }
    return null;
  }

  Future<void> _handleRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final deviceId = await _getDeviceId();
      if (deviceId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not identify this device.')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final student = await _studentRepo.registerDevice(
        _codeController.text.trim(),
        deviceId,
      ).timeout(const Duration(seconds: 10));

      setState(() => _isLoading = false);

      if (student != null) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => StudentDashboardScreen(student: student),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Invalid registration code. Please try again.')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration error: ${e.toString().split('\n').first}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Registration'),
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
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.sky.withOpacity(0.15),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: SvgPicture.asset(
                      'assets/images/logo.svg',
                      width: 90,
                      height: 90,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.xxl),
                Text(
                  'Register your device',
                  textAlign: TextAlign.center,
                  style: AppType.display(
                    context,
                    fontSize: 26,
                    weight: FontWeight.w700,
                    color: AppColors.textPrimary(isDark),
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  'Enter the registration code provided by your instructor to link this device to your student profile.',
                  textAlign: TextAlign.center,
                  style: AppType.body(context, fontSize: 14, color: AppColors.textSecondary(isDark)),
                ),
                const SizedBox(height: AppSpace.xxxl + 4),
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Registration code',
                    prefixIcon: Icon(Icons.vpn_key_rounded),
                  ),
                  style: AppType.data(context, fontSize: 15),
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter a code' : null,
                ),
                const SizedBox(height: AppSpace.xxl),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton(
                            onPressed: _handleRegistration,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.sky,
                              foregroundColor: Colors.white,
                              shadowColor: AppColors.sky.withOpacity(0.4),
                              elevation: 4,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Register device'),
                          ),
                          if (true) ...[
                            const SizedBox(height: AppSpace.lg),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.developer_mode_rounded),
                              label: const Text('Developer login (bypass code)'),
                              onPressed: _handleDevRegistration,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.amber,
                                side: const BorderSide(color: AppColors.amber, width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: AppRadius.smR),
                              ),
                            ),
                          ],
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleDevRegistration() async {
    setState(() => _isLoading = true);
    final deviceId = await _getDeviceId();

    if (deviceId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not identify this device.')),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    final List<Student> students = await _studentRepo.getAllStudents();

    if (students.isNotEmpty) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      final selectedStudent = await showDialog<Student>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Select student (dev bypass)', style: AppType.display(context, fontSize: 17, weight: FontWeight.w600)),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.xlR),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: students.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final student = students[index];
                  return ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person),
                    ),
                    title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Course ID: ${student.courseId}'),
                    onTap: () => Navigator.of(context).pop(student),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  final newStudent = await _studentRepo.addStudent(
                    'Demo Student ${students.length + 1}',
                    students.first.courseId,
                  );
                  if (context.mounted) Navigator.of(context).pop(newStudent);
                },
                child: const Text('Create New Demo Student'),
              ),
            ],
          );
        },
      );

      if (selectedStudent != null) {
        setState(() => _isLoading = true);
        final updatedStudent = await _studentRepo.registerDevice(
          selectedStudent.deviceAppId,
          deviceId,
        );
        setState(() => _isLoading = false);

        if (updatedStudent != null && mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => StudentDashboardScreen(student: updatedStudent),
            ),
          );
        }
      }
    } else {
      final teacherRepo = TeacherRepository();
      final courseRepo = CourseRepository();

      final teacher = await teacherRepo.upsertTeacher(Teacher(
        name: 'Demo Teacher 1',
        email: 'teacher1@school.edu',
      ));

      final course = await courseRepo.createCourse(Course(
        teacherId: teacher.id!,
        name: 'Demo Course 1',
        schoolName: 'Demo School',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
      ));

      final student = await _studentRepo.addStudent('Demo Student 1', course.id!);

      final updatedStudent = await _studentRepo.registerDevice(
        student.deviceAppId,
        deviceId,
      );

      setState(() => _isLoading = false);

      if (updatedStudent != null && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => StudentDashboardScreen(student: updatedStudent),
          ),
        );
      }
    }
  }
}
