import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'teacher.dart';
import 'google_auth_service.dart';
import 'google_sheets_automation_service.dart';
import 'services/supabase_auth_service.dart';
import 'teacher_dashboard_screen.dart';
import 'teacher_repository.dart';
import 'ui/design_tokens.dart';

class TeacherLoginScreen extends StatefulWidget {
  const TeacherLoginScreen({super.key});

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
  
  bool _isLoading = false;
  bool _isSignUpMode = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    setState(() => _isLoading = true);
    final authService = GoogleAuthService();
    final automationService = GoogleSheetsAutomationService();
    final teacherRepo = TeacherRepository();
    final GoogleSignInAccount? user = await authService.signIn();

    if (user != null) {
      // Create a Teacher object from the Google user.
      final newTeacher = Teacher(
        name: user.displayName ?? 'No Name',
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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => TeacherDashboardScreen(teacher: savedTeacher),
        ),
      );
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

    try {
      if (_isSignUpMode) {
        final response = await authService.signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          name: _nameController.text.trim(),
        );

        if (response.user != null) {
          final newTeacher = Teacher(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
          );
          
          final savedTeacher = await teacherRepo.upsertTeacher(newTeacher);

          try {
            final directory = await getApplicationDocumentsDirectory();
            final file = File('${directory.path}/.logged_in_teacher_email');
            await file.writeAsString(savedTeacher.email);
          } catch (_) {}

          if (!mounted) return;
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registration successful!'),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => TeacherDashboardScreen(teacher: savedTeacher),
            ),
          );
        }
      } else {
        final response = await authService.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        if (response.user != null) {
          final email = response.user!.email!;
          final metadataName = response.user!.userMetadata?['name'] as String?;
          
          final newTeacher = Teacher(
            name: metadataName ?? email.split('@').first,
            email: email,
          );

          final savedTeacher = await teacherRepo.upsertTeacher(newTeacher);

          try {
            final directory = await getApplicationDocumentsDirectory();
            final file = File('${directory.path}/.logged_in_teacher_email');
            await file.writeAsString(savedTeacher.email);
          } catch (_) {}

          if (!mounted) return;

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => TeacherDashboardScreen(teacher: savedTeacher),
            ),
          );
        }
      }
    } on supabase.AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
        ),
      );
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
        try {
          final directory = await getApplicationDocumentsDirectory();
          final file = File('${directory.path}/.logged_in_teacher_email');
          await file.writeAsString(selectedTeacher.email);
        } catch (_) {}

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => TeacherDashboardScreen(teacher: selectedTeacher),
          ),
        );
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

      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => TeacherDashboardScreen(teacher: savedTeacher),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Portal'),
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
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.xxl, vertical: AppSpace.huge - 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.indigoDark.withOpacity(0.15),
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
                  'Faculty Sign-In',
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
                  'Manage courses, classrooms, and check-in rosters',
                  textAlign: TextAlign.center,
                  style: AppType.body(context, fontSize: 14, color: AppColors.textSecondary(isDark)),
                ),
                const SizedBox(height: AppSpace.xxxl),
                
                // Premium Pill Tab Switcher (Hidden but preserved in code)
                if (false)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate800 : AppColors.slate200,
                    borderRadius: AppRadius.lgR,
                  ),
                  child: TabBar(
                    controller: _tabController,
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: AppRadius.mdR,
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.textSecondary(isDark),
                    labelStyle: AppType.body(context, weight: FontWeight.w700),
                    tabs: const [
                      Tab(text: 'Google Sign-In'),
                      Tab(text: 'Email / Supabase'),
                    ],
                  ),
                ),
                
                if (false) const SizedBox(height: 24),
                
                // Form Card Container
                Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.xxl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Supabase Email Sign In Form (Rendered directly to prevent squashed UI)
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isSignUpMode) ...[
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
                                  labelText: 'Faculty email',
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
                                      child: Text(_isSignUpMode ? 'Register account' : 'Sign in'),
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
                            ],
                          ),
                        ),

                        // Google Sign-In Tab (Hidden but preserved in code)
                        if (false)
                          SizedBox(
                            height: 320,
                            child: TabBarView(
                              controller: _tabController,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'Access your faculty account securely via Google Authentication.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        height: 1.4,
                                        color: isDark ? Colors.grey[350] : AppColors.slate600,
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.login_rounded),
                                      label: const Text('Sign in with Google'),
                                      onPressed: () => _handleGoogleSignIn(context),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: theme.colorScheme.primary,
                                        foregroundColor: Colors.white,
                                        shadowColor: theme.colorScheme.primary.withOpacity(0.4),
                                        elevation: 4,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                
                // Developer Bypass (Hidden but preserved in code)
                if (false) ...[
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
