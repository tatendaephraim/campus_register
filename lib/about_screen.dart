import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'ui/design_tokens.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('About Campus Register'),
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
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl, vertical: AppSpace.xxl),
          children: [
            // Designer Branding Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.xlR,
                side: BorderSide(
                  color: AppColors.border(isDark),
                  width: 1.5,
                ),
              ),
              color: isDark ? AppColors.slate800.withValues(alpha: 0.6) : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.xxl),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                      child: SvgPicture.asset(
                        'assets/images/logo.svg',
                        width: 48,
                        height: 48,
                      ),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    Text(
                      'DESIGNED & ENGINEERED BY',
                      style: AppType.body(
                        context,
                        fontSize: 11,
                        weight: FontWeight.w700,
                        color: isDark ? AppColors.indigoLight : theme.colorScheme.primary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      'Cresco Systems Labs',
                      style: AppType.display(
                        context,
                        fontSize: 23,
                        weight: FontWeight.w700,
                        color: AppColors.textPrimary(isDark),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: AppSpace.md),
                    Text(
                      'Building precision verification systems for academic institutions, with biometric and spatial telemetry that ensure real-time attendance integrity.',
                      textAlign: TextAlign.center,
                      style: AppType.body(context, fontSize: 14, color: AppColors.textSecondary(isDark), height: 1.45),
                    ),
                    const SizedBox(height: AppSpace.xl),
                    // Developer Web link button
                    InkWell(
                      onTap: () async {
                        final Uri url = Uri.parse('https://tatendaephraim.github.io/');
                        try {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        } catch (_) {
                          try {
                            await launchUrl(url);
                          } catch (_) {
                            Clipboard.setData(const ClipboardData(
                                text: 'https://tatendaephraim.github.io/'));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Could not launch website. Link copied to clipboard!'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: theme.colorScheme.primary,
                                ),
                              );
                            }
                          }
                        }
                      },
                      borderRadius: AppRadius.lgR,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: AppRadius.lgR,
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.15),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.public_rounded,
                                size: 18, color: theme.colorScheme.primary),
                            const SizedBox(width: AppSpace.sm),
                            Text(
                              'Visit Website',
                              style: AppType.data(
                                context,
                                color: theme.colorScheme.primary,
                                weight: FontWeight.w600,
                              ).copyWith(decoration: TextDecoration.underline),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.open_in_new_rounded,
                                size: 14, color: theme.colorScheme.primary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpace.xxxl - 4),

            // Section Header: Security
            _buildSectionHeader(context, theme, isDark, 'SECURITY ARCHITECTURE & FLOWS', Icons.shield_outlined),
            const SizedBox(height: AppSpace.md),

            // Security Details Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSecurityFeature(
                      context,
                      theme,
                      isDark,
                      title: '1-to-1 device pairing (hardware locking)',
                      description: 'During registration, a single-use 6-digit invitation code binds the user\'s profile directly to their phone\'s unique hardware-bound ID (Android Secure ID or iOS Vendor ID). Once bound, the database locks the account to that device, rejecting registrations from other devices.',
                    ),
                    const Divider(height: 24),
                    _buildSecurityFeature(
                      context,
                      theme,
                      isDark,
                      title: 'Secure Enclave biometric validation',
                      description: 'Biometric authorization prompts are delegated directly to the device\'s hardware Secure Enclave. The app only receives a verified cryptographic assertion token. Biometrics are never sent over the network or stored in the cloud.',
                    ),
                    const Divider(height: 24),
                    _buildSecurityFeature(
                      context,
                      theme,
                      isDark,
                      title: 'Anti-buddy geofence interlock',
                      description: 'Even if a student registers their fingerprint on another device, check-ins require physical location and altitude proximity matching the classroom. Because devices are locked to profiles, students cannot sign in remotely.',
                    ),
                    const Divider(height: 24),
                    _buildSecurityFeature(
                      context,
                      theme,
                      isDark,
                      title: 'Cryptographic key invalidation',
                      description: 'Generating on-device cryptographic key pairs bound to biometric enrollments ensures that registering a new fingerprint on the device instantly invalidates existing keys, logging out potential spoofing attempts.',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpace.xxxl - 4),

            // Section Header: Math
            _buildSectionHeader(context, theme, isDark, 'MATHEMATICAL MODELS & TELEMETRY', Icons.functions_rounded),
            const SizedBox(height: AppSpace.md),

            // Mathematical Formulas Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // PIP
                    _buildMathFormula(
                      context,
                      theme,
                      isDark,
                      title: '1. Ray-casting geofencing check',
                      explanation: 'The system determines if a student is physically present inside the designated classroom polygon boundary. It projects an imaginary horizontal line (ray) from the student\'s GPS coordinates. By analyzing intersections with classroom walls, the app verifies classroom presence and prevents remote spoofing.',
                    ),
                    const Divider(height: 32),
                    // Outlined distance
                    _buildMathFormula(
                      context,
                      theme,
                      isDark,
                      title: '2. WGS84 ellipsoid geodesic distance computation',
                      explanation: 'Computes the absolute physical displacement between the student\'s device and the central coordinates of a circular geofence using the WGS84 geodetic model. This provides sub-meter accuracy over a reference ellipsoid, replacing less precise flat-plane or simple spherical Haversine approximations.',
                    ),
                    const Divider(height: 32),
                    // Point to Segment
                    _buildMathFormula(
                      context,
                      theme,
                      isDark,
                      title: '3. Drift & lateral edge correction',
                      explanation: 'Standard GPS signals suffer from atmospheric drift. To compensate, the system projects the student\'s coordinates onto the nearest classroom wall segment. This ensures that students sitting close to walls or doors are not incorrectly flagged as absent, allowing a lateral tolerance buffer of 5.0 meters outwards.',
                    ),
                    const Divider(height: 32),
                    // Altitude
                    _buildMathFormula(
                      context,
                      theme,
                      isDark,
                      title: '4. Volumetric altitude check',
                      explanation: 'To restrict check-ins from other floors (e.g. students directly above or below the lecture room), the app monitors GPS-derived altitude telemetry. It compares the live reading against a floor validation range of -8.0m (lower tolerance) to +12.0m (or configured upper tolerance) around the classroom ground level to enforce a strict vertical geofence ceiling.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, ThemeData theme, bool isDark, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.secondary),
        const SizedBox(width: AppSpace.sm),
        Text(
          title,
          style: AppType.body(
            context,
            weight: FontWeight.w700,
            color: isDark ? Colors.grey[300] : AppColors.slate600,
            letterSpacing: 0.8,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityFeature(
    BuildContext context,
    ThemeData theme,
    bool isDark, {
    required String title,
    required String description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpace.sm + 2),
            Expanded(
              child: Text(
                title,
                style: AppType.display(
                  context,
                  fontSize: 15.5,
                  weight: FontWeight.w600,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.sm - 2),
        Padding(
          padding: const EdgeInsets.only(left: AppSpace.lg + 2),
          child: Text(
            description,
            style: AppType.body(context, fontSize: 13.5, color: AppColors.textSecondary(isDark), height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _buildMathFormula(
    BuildContext context,
    ThemeData theme,
    bool isDark, {
    required String title,
    required String explanation,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppType.display(context, fontSize: 15, weight: FontWeight.w600, color: AppColors.textPrimary(isDark)),
        ),
        const SizedBox(height: AppSpace.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpace.lg),
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate900.withValues(alpha: 0.4) : AppColors.slate50,
            borderRadius: AppRadius.lgR,
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFEEF2F6),
              width: 1,
            ),
          ),
          child: Text(
            explanation,
            style: AppType.data(context, fontSize: 12.5, color: isDark ? Colors.grey[300] : AppColors.slate600, weight: FontWeight.w400).copyWith(height: 1.5),
          ),
        ),
      ],
    );
  }
}
