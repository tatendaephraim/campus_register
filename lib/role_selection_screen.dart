import 'package:flutter/material.dart';
import 'student_registration_screen.dart';
import 'teacher_login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0F172A), // Slate 900
                    const Color(0xFF1E1B4B), // Deep Indigo 950
                  ]
                : [
                    const Color(0xFFF1F5F9), // Slate 100
                    const Color(0xFFE0E7FF), // Indigo 100
                  ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                
                // Glowing Brand Logo
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(isDark ? 0.25 : 0.15),
                          blurRadius: 32,
                          spreadRadius: 8,
                        )
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.fingerprint_rounded,
                        size: 72,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Heading
                Text(
                  'Campus Register',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Volumetric Badge Tag
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981), // Pulsing green dot
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Volumetric 3D Tracking Enabled',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const Spacer(flex: 2),
                
                Text(
                  'Identify yourself to proceed',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Teacher Card
                _buildRoleCard(
                  context,
                  title: "I'm a Teacher",
                  subtitle: "Create courses, set timetables, manage venues, and sync reports",
                  icon: Icons.school_rounded,
                  color: const Color(0xFF6366F1), // Indigo
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => const TeacherLoginScreen(),
                    ));
                  },
                ),
                const SizedBox(height: 16),
                
                // Student Card
                _buildRoleCard(
                  context,
                  title: "I'm a Student",
                  subtitle: "Register your device, view timetable, and sign in securely",
                  icon: Icons.person_pin_rounded,
                  color: const Color(0xFF0EA5E9), // Sky Blue
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => const StudentRegistrationScreen(),
                    ));
                  },
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
      ),
      color: isDark ? const Color(0xFF1E293B).withOpacity(0.6) : Colors.white.withOpacity(0.9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: color.withOpacity(0.15),
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
