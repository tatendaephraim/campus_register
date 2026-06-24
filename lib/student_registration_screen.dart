import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';

import 'student.dart';
import 'student_repository.dart';
import 'student_dashboard_screen.dart';
import 'teacher.dart';
import 'course.dart';
import 'teacher_repository.dart';
import 'course_repository.dart';

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

    final deviceId = await _getDeviceId();
    if (deviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not identify this device.')),
      );
      setState(() => _isLoading = false);
      return;
    }

    final student = await _studentRepo.registerDevice(
      _codeController.text.trim(),
      deviceId,
    );

    setState(() => _isLoading = false);

    if (student != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => StudentDashboardScreen(student: student),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Invalid registration code. Please try again.')),
      );
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
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.person_pin_rounded,
                  size: 80,
                  color: Color(0xFF0EA5E9),
                ),
                const SizedBox(height: 24),
                Text(
                  'Register Your Device',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the registration code provided by your instructor to link this device to your student profile.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 36),
                TextFormField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    labelText: 'Registration Code',
                    prefixIcon: const Icon(Icons.vpn_key_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  ),
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter a code' : null,
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton(
                            onPressed: _handleRegistration,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0EA5E9),
                              foregroundColor: Colors.white,
                              shadowColor: const Color(0xFF0EA5E9).withOpacity(0.4),
                              elevation: 4,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Register Device'),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.developer_mode_rounded),
                            label: const Text('Developer Login (Bypass Code)'),
                            onPressed: _handleDevRegistration,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFF59E0B),
                              side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
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
            title: const Text('Select Student (Dev Bypass)'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
