
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'student.dart';
import 'student_repository.dart';
import 'student_dashboard_screen.dart';
import 'services/device_identity.dart';
import 'ui/design_tokens.dart';
import 'utils/utils.dart';

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

  Future<String?> _getDeviceId() => DeviceIdentity.current();

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
      ).timeout(const Duration(seconds: 40));

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
                          color: AppColors.sky.withValues(alpha: 0.15),
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
                              shadowColor: AppColors.sky.withValues(alpha: 0.4),
                              elevation: 4,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Register device'),
                          ),
                          if (devBypassEnabled) ...[
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
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No registered students found. Please register students on the teacher portal first.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
