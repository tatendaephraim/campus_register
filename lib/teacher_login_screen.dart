import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'teacher.dart';
import 'google_auth_service.dart';
import 'google_sheets_automation_service.dart';
import 'services/supabase_auth_service.dart';
import 'teacher_dashboard_screen.dart';
import 'teacher_repository.dart';

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
  final _nameController = TextEditingController();
  
  bool _isLoading = false;
  bool _isSignUpMode = false;
  bool _obscurePassword = true;

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
            title: const Text('Select Teacher (Dev Bypass)'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.school_rounded,
                  size: 72,
                  color: Color(0xFF4F46E5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Faculty Sign-In',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage courses, classrooms, and check-in rosters',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Premium Pill Tab Switcher
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                    tabs: const [
                      Tab(text: 'Google Sign-In'),
                      Tab(text: 'Email / Supabase'),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Form Card Container
                Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: SizedBox(
                      height: 320,
                      child: TabBarView(
                        controller: _tabController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          // Google Sign In Tab
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Access your faculty account securely via Google Authentication.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  height: 1.4,
                                  color: isDark ? Colors.grey[350] : const Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(height: 32),
                              _isLoading
                                  ? const Center(child: CircularProgressIndicator())
                                  : ElevatedButton.icon(
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
                          
                          // Supabase Email Sign In Tab
                          Form(
                            key: _formKey,
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_isSignUpMode) ...[
                                    TextFormField(
                                      controller: _nameController,
                                      decoration: const InputDecoration(
                                        labelText: 'Full Name',
                                        prefixIcon: Icon(Icons.person),
                                      ),
                                      validator: (val) => val == null || val.isEmpty ? 'Enter your name' : null,
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: const InputDecoration(
                                      labelText: 'Faculty Email',
                                      prefixIcon: Icon(Icons.email),
                                    ),
                                    validator: (val) => val == null || !val.contains('@') ? 'Enter a valid email' : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      prefixIcon: const Icon(Icons.lock),
                                      suffixIcon: IconButton(
                                        icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                      ),
                                    ),
                                    validator: (val) => val == null || val.length < 6 ? 'Password must be at least 6 characters' : null,
                                  ),
                                  const SizedBox(height: 20),
                                  _isLoading
                                      ? const Center(child: CircularProgressIndicator())
                                      : ElevatedButton(
                                          onPressed: _handleSupabaseAuth,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: theme.colorScheme.primary,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                          ),
                                          child: Text(_isSignUpMode ? 'Register Account' : 'Sign In'),
                                        ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () => setState(() => _isSignUpMode = !_isSignUpMode),
                                    child: Text(_isSignUpMode ? 'Already have an account? Sign In' : "Don't have an account? Register"),
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
                
                const Divider(height: 48),
                
                // Developer Bypass
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
    );
  }
}
