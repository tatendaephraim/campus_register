import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'student_registration_screen.dart';
import 'teacher_login_screen.dart';
import 'ui/design_tokens.dart';

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
                ? [AppColors.slate900, AppColors.indigoDeep]
                : [AppColors.slate100, const Color(0xFFE0E7FF)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.xxl, vertical: AppSpace.xxxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),

                // Glowing brand mark
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.25),
                          blurRadius: 36,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: SvgPicture.asset(
                      'assets/images/logo.svg',
                      width: 110,
                      height: 110,
                    ),
                  ),
                ),

                const SizedBox(height: AppSpace.xxxl),

                // Heading — display face carries the brand identity
                Text(
                  'Campus Register',
                  textAlign: TextAlign.center,
                  style: AppType.display(
                    context,
                    fontSize: 34,
                    weight: FontWeight.w700,
                    color: AppColors.textPrimary(isDark),
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: AppSpace.sm),

                // Volumetric status badge
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: AppDeco.statusPill(theme.colorScheme.primary, opacity: 0.1),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Text(
                          'VOLUMETRIC 3D TRACKING ENABLED',
                          style: AppType.body(
                            context,
                            fontSize: 11,
                            color: theme.colorScheme.primary,
                            weight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                Text(
                  'IDENTIFY YOURSELF TO PROCEED',
                  textAlign: TextAlign.center,
                  style: AppType.body(
                    context,
                    fontSize: 13,
                    color: AppColors.textSecondary(isDark),
                    weight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpace.lg),

                _buildRoleCard(
                  context,
                  title: "I'm an Employee/Educator/Student",
                  subtitle: 'If you have an account sign in here (Employee/Educator), but students sign in below'
                      ',unless you do not have an account',
                  icon: Icons.school_rounded,
                  color: theme.colorScheme.primary,
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => const TeacherLoginScreen(),
                    ));
                  },
                ),
                const SizedBox(height: AppSpace.lg),

                _buildRoleCard(
                  context,
                  title: "I'm a Student",
                  subtitle: 'Register your device, view timetable, and sign in securely',
                  icon: Icons.person_pin_rounded,
                  color: AppColors.sky,
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
        borderRadius: AppRadius.xlR,
        side: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.06) : AppColors.slate200,
          width: 1.5,
        ),
      ),
      color: isDark ? AppColors.slate800.withOpacity(0.6) : Colors.white.withOpacity(0.92),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.xlR,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl, vertical: AppSpace.xxl),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpace.lg),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: AppRadius.lgR,
                  border: Border.all(color: color.withOpacity(0.15), width: 1),
                ),
                child: Icon(icon, size: 30, color: color),
              ),
              const SizedBox(width: AppSpace.lg + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppType.display(
                        context,
                        fontSize: 18,
                        weight: FontWeight.w600,
                        color: AppColors.textPrimary(isDark),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: AppType.body(
                        context,
                        fontSize: 13,
                        color: AppColors.textSecondary(isDark),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.04) : AppColors.slate100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
