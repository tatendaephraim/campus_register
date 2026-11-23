import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'teacher.dart';
import 'student.dart';
import 'organization.dart';
import 'google_auth_service.dart';
import 'google_sheets_automation_service.dart';
import 'services/supabase_auth_service.dart';
import 'teacher_dashboard_screen.dart';
import 'admin_dashboard_screen.dart';
import 'teacher_repository.dart';
import 'student_repository.dart';
import 'organization_repository.dart';
import 'pending_approval_screen.dart';
import 'role_selection_screen.dart';
import 'ui/design_tokens.dart';

class TeacherLoginScreen extends StatefulWidget {
  final bool initialSignUpMode;
  final String initialRequestedRole;

  const TeacherLoginScreen({
    super.key,
    this.initialSignUpMode = false,
    this.initialRequestedRole = 'employee',
  });

  @override
  State<TeacherLoginScreen> createState() => _TeacherLoginScreenState();
}

class _TeacherLoginScreenState extends State<TeacherLoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();

  final _orgNameController = TextEditingController();
  final _orgAddressController = TextEditingController();
  final _orgCountryController = TextEditingController();
  final _orgCodeController = TextEditingController();
  
  bool _isLoading = false;
  bool _isSignUpMode = false;
  bool _createOrganization = false;
  String _orgType = 'school'; // 'school', 'college', 'business', 'organization'
  String _requestedRole = 'employee'; // 'employee', 'student'
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _isSignUpMode = widget.initialSignUpMode;
    _requestedRole = widget.initialRequestedRole;
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _orgNameController.dispose();
    _orgAddressController.dispose();
    _orgCountryController.dispose();
    _orgCodeController.dispose();
    super.dispose();
  }

  Future<void> _navigateToDashboard(BuildContext context, Teacher teacher) async {
    final theme = Theme.of(context);
    if (teacher.role != 'admin') {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      String? currentDeviceId;
      try {
        final deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          currentDeviceId = androidInfo.id;
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          currentDeviceId = iosInfo.identifierForVendor;
        }
      } catch (_) {}

      if (context.mounted) {
        Navigator.of(context).pop(); // dismiss loading
      }

      if (currentDeviceId != null) {
        if (teacher.deviceAppId == null || teacher.deviceAppId!.isEmpty) {
          await TeacherRepository().updateTeacherDeviceId(teacher.id!, currentDeviceId);
          teacher = Teacher(
            id: teacher.id,
            organizationId: teacher.organizationId,
            name: teacher.name,
            email: teacher.email,
            googleSheetUrl: teacher.googleSheetUrl,
            role: teacher.role,
            isApproved: teacher.isApproved,
            deviceAppId: currentDeviceId,
          );
        } else if (teacher.deviceAppId != currentDeviceId) {
          if (context.mounted) {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text('Device Link Request', style: AppType.display(dialogContext, fontSize: 16.5, weight: FontWeight.w600)),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.xlR),
                content: const Text(
                  'This account is registered to another device.\n\n'
                  'Would you like to reset the binding and register this device instead?'
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: Colors.white),
                    child: const Text('Link Device'),
                  ),
                ],
              ),
            );

            if (confirm == true) {
              await TeacherRepository().updateTeacherDeviceId(teacher.id!, currentDeviceId);
              teacher = Teacher(
                id: teacher.id,
                organizationId: teacher.organizationId,
                name: teacher.name,
                email: teacher.email,
                googleSheetUrl: teacher.googleSheetUrl,
                role: teacher.role,
                isApproved: teacher.isApproved,
                deviceAppId: currentDeviceId,
              );
              if (!context.mounted) return;
              if (teacher.role.trim().toLowerCase() == 'admin') {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => AdminDashboardScreen(admin: teacher)),
                );
              } else {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => TeacherDashboardScreen(teacher: teacher)),
                );
              }
            }
          }
          return;
        }
      }
    }

    if (!context.mounted) return;

    if (teacher.role.trim().toLowerCase() == 'admin') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => AdminDashboardScreen(admin: teacher),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => TeacherDashboardScreen(teacher: teacher),
        ),
      );
    }
  }

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    setState(() => _isLoading = true);
    final authService = GoogleAuthService();
    final automationService = GoogleSheetsAutomationService();
    final teacherRepo = TeacherRepository();
    final GoogleSignInAccount? user = await authService.signIn();

    if (user != null) {
      // Create a new teacher record
      final newTeacher = Teacher(
        name: user.displayName ?? '',
        email: user.email,
      );

      // Save the teacher to the local database and Supabase.
      var savedTeacher = await teacherRepo.upsertTeacher(newTeacher);

      // --- AUTOMATION STEP ---
      // If the teacher doesn't have a sheet URL, create one.
      if (savedTeacher.googleSheetUrl == null ||
          savedTeacher.googleSheetUrl!.isEmpty) {
        final sheetUrl = await automationService.createAndDeploy(
            user, savedTeacher.name); // Using teacher name for demo
        if (sheetUrl != null) {
          // Save the new URL to the teacher's record
          final updatedTeacher = Teacher(
              id: savedTeacher.id,
              name: savedTeacher.name,
              email: savedTeacher.email,
              googleSheetUrl: sheetUrl);
          savedTeacher = await teacherRepo.upsertTeacher(updatedTeacher);
        }
      }

      try {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/.logged_in_teacher_email');
        await file.writeAsString(savedTeacher.email);
      } catch (_) {}

      setState(() => _isLoading = false);

      if (!mounted) return;

      // Navigate to the dashboard, replacing the login screen.
      _navigateToDashboard(context, savedTeacher);
    } else {
      setState(() => _isLoading = false);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google Sign-in failed. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleSupabaseAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final authService = SupabaseAuthService();
    final teacherRepo = TeacherRepository();
    final studentRepo = StudentRepository();
    final orgRepo = OrganizationRepository();

    try {
      if (_isSignUpMode) {
        if (_requestedRole == 'student' && !_createOrganization) {
          final org = await orgRepo.getOrganizationByCode(_orgCodeController.text.trim());
          if (org == null) {
            throw 'Invalid Organization Code. Please verify and try again.';
          }

          // 1. Sign up to Supabase Auth first
          final response = await authService.signUpWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            name: _nameController.text.trim(),
          );

          if (response.user != null) {
            final regCode = (100000 + Random().nextInt(900000)).toString();
            await studentRepo.addStudentToOrganization(
              _nameController.text.trim(),
              regCode,
              org.id!,
              email: _emailController.text.trim(),
            );

            setState(() => _isLoading = false);

            if (mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  title: const Text('Registration Pending'),
                  content: Text(
                    'Your request to join "${org.name}" has been submitted successfully.\n\n'
                    'Once approved by the Administrator, you will be issued a registration code to log in as a Student from the home screen.'
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
                          (route) => false,
                        );
                      },
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            }
          }
          return;
        }

        Organization? targetOrg;
        if (_createOrganization) {
          final code = orgRepo.generateOrganizationCode();
          targetOrg = await orgRepo.createOrganization(Organization(
            name: _orgNameController.text.trim(),
            address: _orgAddressController.text.trim(),
            country: _orgCountryController.text.trim(),
            type: _orgType,
            code: code,
          ));
        } else {
          targetOrg = await orgRepo.getOrganizationByCode(_orgCodeController.text.trim());
          if (targetOrg == null) {
            throw 'Invalid Organization Code. Please verify and try again.';
          }
        }

        final response = await authService.signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          name: _nameController.text.trim(),
        );

        if (response.user != null) {
          final newTeacher = Teacher(
            organizationId: targetOrg.id!,
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            role: _createOrganization ? 'admin' : 'teacher',
            isApproved: _createOrganization ? 1 : 0,
          );
          
          final savedTeacher = await teacherRepo.upsertTeacher(newTeacher);

          try {
            final directory = await getApplicationDocumentsDirectory();
            final file = File('${directory.path}/.logged_in_teacher_email');
            await file.writeAsString(savedTeacher.email);
          } catch (_) {}

          if (!mounted) return;
          
          if (_createOrganization) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Organization and Admin account registered successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            _navigateToDashboard(context, savedTeacher);
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => PendingApprovalScreen(
                  userName: savedTeacher.name,
                  userEmail: savedTeacher.email,
                  orgName: targetOrg!.name,
                  orgCode: targetOrg.code,
                ),
              ),
            );
          }
        }
      } else {
        final response = await authService.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        if (response.user != null) {
          final email = response.user!.email!;
          final teacher = await teacherRepo.getTeacherByEmail(email);

          if (teacher.isApproved == 0) {
            final org = await orgRepo.getOrganizationById(teacher.organizationId!);
            if (!mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => PendingApprovalScreen(
                  userName: teacher.name,
                  userEmail: teacher.email,
                  orgName: org?.name ?? 'Unknown Organization',
                  orgCode: org?.code ?? '',
                ),
              ),
            );
            return;
          }

          try {
            final directory = await getApplicationDocumentsDirectory();
            final file = File('${directory.path}/.logged_in_teacher_email');
            await file.writeAsString(teacher.email);
          } catch (_) {}

          if (!mounted) return;

          _navigateToDashboard(context, teacher);
        }
      }
    } on supabase.AuthException catch (e) {
      if (!mounted) return;
      if (e.message.toLowerCase().contains('email not confirmed')) {
        final email = _emailController.text.trim();
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Email Verification Required'),
            content: Text('Your account has been approved by the Admin, but your email address ($email) is not yet verified in our authentication system.\n\nPlease check your email inbox and click the verification link. If you did not receive the email, tap "Resend Email".'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final scaffoldMessenger = ScaffoldMessenger.of(context);

                  navigator.pop(); // pop first dialog

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(child: CircularProgressIndicator()),
                  );

                  try {
                    await supabase.Supabase.instance.client.auth.resend(
                      type: supabase.OtpType.signup,
                      email: email,
                    );
                    navigator.pop(); // pop loading spinner
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Verification email resent successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (err) {
                    navigator.pop(); // pop loading spinner
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Failed to resend: $err'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('Resend Email'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Authentication failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDevSignIn(BuildContext context) async {
    final teacherRepo = TeacherRepository();
    final orgRepo = OrganizationRepository();
    final List<Teacher> teachers = await teacherRepo.getAllTeachers();

    if (teachers.isNotEmpty) {
      if (!context.mounted) return;
      final selectedTeacher = await showDialog<Teacher>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Select teacher (dev bypass)', style: AppType.display(context, fontSize: 17, weight: FontWeight.w600)),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.xlR),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: teachers.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final teacher = teachers[index];
                  return ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person),
                    ),
                    title: Text(teacher.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(teacher.email),
                    onTap: () => Navigator.of(context).pop(teacher),
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
                  final newTeacher = Teacher(
                    name: 'Demo Teacher ${teachers.length + 1}',
                    email: 'teacher${teachers.length + 1}@school.edu',
                  );
                  final saved = await teacherRepo.upsertTeacher(newTeacher);
                  if (context.mounted) Navigator.of(context).pop(saved);
                },
                child: const Text('Create New Demo Teacher'),
              ),
            ],
          );
        },
      );

      if (selectedTeacher != null && context.mounted) {
        if (selectedTeacher.isApproved == 0) {
          final org = await orgRepo.getOrganizationById(selectedTeacher.organizationId!);
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => PendingApprovalScreen(
                userName: selectedTeacher.name,
                userEmail: selectedTeacher.email,
                orgName: org?.name ?? 'Unknown Organization',
                orgCode: org?.code ?? '',
              ),
            ),
          );
          return;
        }

        try {
          final directory = await getApplicationDocumentsDirectory();
          final file = File('${directory.path}/.logged_in_teacher_email');
          await file.writeAsString(selectedTeacher.email);
        } catch (_) {}

        _navigateToDashboard(context, selectedTeacher);
      }
    } else {
      final newTeacher = Teacher(
        name: 'Demo Teacher 1',
        email: 'teacher1@school.edu',
      );
      final savedTeacher = await teacherRepo.upsertTeacher(newTeacher);

      try {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/.logged_in_teacher_email');
        await file.writeAsString(savedTeacher.email);
      } catch (_) {}

      if (context.mounted) {
        _navigateToDashboard(context, savedTeacher);
      }
    }
  }

  Widget _buildCourseDashboardCard(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    Student student,
  ) {
    return const Card(
      margin: EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.sm),
      child: Padding(
        padding: EdgeInsets.all(AppSpace.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_requestedRole == 'student' ? 'Student Portal' : 'Faculty Portal'),
        elevation: 0,
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
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl, vertical: AppSpace.huge - 4),
          children: [
            Center(
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.indigoDark.withValues(alpha: 0.15),
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
            const SizedBox(height: AppSpace.lg),
            Text(
              _requestedRole == 'student' ? 'Student Signup' : 'Organization Portal',
              textAlign: TextAlign.center,
              style: AppType.display(
                context,
                fontSize: 28,
                weight: FontWeight.w700,
                color: AppColors.textPrimary(isDark),
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              _requestedRole == 'student'
                  ? 'Register an email profile to join your campus organization'
                  : 'Manage courses, employees, geofences, and sync reports',
              textAlign: TextAlign.center,
              style: AppType.body(context, fontSize: 14, color: AppColors.textSecondary(isDark)),
            ),
            const SizedBox(height: AppSpace.xxxl),
            
            Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.xxl),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isSignUpMode) ...[
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.slate900 : AppColors.slate100,
                            borderRadius: AppRadius.mdR,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() {
                                    _requestedRole = 'employee';
                                  }),
                                  borderRadius: AppRadius.smR,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _requestedRole == 'employee'
                                          ? theme.colorScheme.primary
                                          : Colors.transparent,
                                      borderRadius: AppRadius.smR,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Employee / Admin',
                                        style: AppType.body(
                                          context,
                                          fontSize: 13,
                                          weight: FontWeight.w700,
                                          color: _requestedRole == 'employee'
                                              ? Colors.white
                                              : AppColors.textSecondary(isDark),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() {
                                    _requestedRole = 'student';
                                    _createOrganization = false;
                                  }),
                                  borderRadius: AppRadius.smR,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _requestedRole == 'student'
                                          ? theme.colorScheme.primary
                                          : Colors.transparent,
                                      borderRadius: AppRadius.smR,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Student',
                                        style: AppType.body(
                                          context,
                                          fontSize: 13,
                                          weight: FontWeight.w700,
                                          color: _requestedRole == 'student'
                                              ? Colors.white
                                              : AppColors.textSecondary(isDark),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpace.md),
                        if (_requestedRole == 'employee') ...[
                          CheckboxListTile(
                            title: const Text('Create a new Organization as Admin', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            value: _createOrganization,
                            onChanged: (val) {
                              setState(() {
                                _createOrganization = val ?? false;
                              });
                            },
                            activeColor: theme.colorScheme.primary,
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          ),
                          const SizedBox(height: AppSpace.md),
                        ],

                        if (_createOrganization && _requestedRole == 'employee') ...[
                          TextFormField(
                            controller: _orgNameController,
                            decoration: const InputDecoration(
                              labelText: 'Organization Name',
                              prefixIcon: Icon(Icons.business_rounded),
                            ),
                            validator: (val) => val == null || val.isEmpty ? 'Enter organization name' : null,
                          ),
                          const SizedBox(height: AppSpace.md),
                          TextFormField(
                            controller: _orgAddressController,
                            decoration: const InputDecoration(
                              labelText: 'Business Address',
                              prefixIcon: Icon(Icons.location_on_rounded),
                            ),
                            validator: (val) => val == null || val.isEmpty ? 'Enter address' : null,
                          ),
                          const SizedBox(height: AppSpace.md),
                          TextFormField(
                            controller: _orgCountryController,
                            decoration: const InputDecoration(
                              labelText: 'Country',
                              prefixIcon: Icon(Icons.flag_rounded),
                            ),
                            validator: (val) => val == null || val.isEmpty ? 'Enter country' : null,
                          ),
                          const SizedBox(height: AppSpace.md),
                          DropdownButtonFormField<String>(
                            value: _orgType,
                            decoration: const InputDecoration(
                              labelText: 'Organization Type',
                              prefixIcon: Icon(Icons.category_rounded),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'school', child: Text('School')),
                              DropdownMenuItem(value: 'college', child: Text('College')),
                              DropdownMenuItem(value: 'business', child: Text('Business')),
                              DropdownMenuItem(value: 'organization', child: Text('Organization')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _orgType = val;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: AppSpace.md),
                        ],

                        if (!_createOrganization) ...[
                          TextFormField(
                            controller: _orgCodeController,
                            decoration: const InputDecoration(
                              labelText: 'Organization Code (9 characters)',
                              prefixIcon: Icon(Icons.vpn_key_rounded),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Enter organization code';
                              }
                              if (val.trim().length != 9) {
                                return 'Code must be exactly 9 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpace.md),
                        ],

                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Full name',
                            prefixIcon: Icon(Icons.person_rounded),
                          ),
                          validator: (val) => val == null || val.isEmpty ? 'Enter your name' : null,
                        ),
                        const SizedBox(height: AppSpace.md),
                      ],

                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email address',
                            prefixIcon: Icon(Icons.email_rounded),
                          ),
                          validator: (val) => val == null || !val.contains('@') ? 'Enter a valid email' : null,
                        ),
                        const SizedBox(height: AppSpace.md),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (val) => val == null || val.length < 6 ? 'Password must be at least 6 characters' : null,
                        ),
                        if (_isSignUpMode) ...[
                          const SizedBox(height: AppSpace.md),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            decoration: InputDecoration(
                              labelText: 'Confirm password',
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureConfirmPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                  return 'Please confirm your password';
                              }
                              if (val != _passwordController.text) {
                                  return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                        ],

                      const SizedBox(height: AppSpace.xl),
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              onPressed: _handleSupabaseAuth,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                              ),
                              child: Text(_isSignUpMode ? (_requestedRole == 'student' ? 'Submit Student Request' : 'Register account') : 'Sign in'),
                            ),
                      const SizedBox(height: AppSpace.sm),
                      TextButton(
                        onPressed: () => setState(() {
                          _isSignUpMode = !_isSignUpMode;
                          _confirmPasswordController.clear();
                        }),
                        child: Text(
                          _isSignUpMode ? 'Already have an account? Sign in' : "Don't have an account? Register",
                          style: AppType.body(context, fontSize: 13, weight: FontWeight.w600),
                        ),
                      ),
                      
                      // Developer Bypass
                      const Divider(height: 48),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.developer_mode_rounded),
                        label: const Text('Developer Login (Bypass Auth)'),
                        onPressed: () => _handleDevSignIn(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFF59E0B),
                          side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
