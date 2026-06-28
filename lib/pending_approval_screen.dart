import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'role_selection_screen.dart';
import 'ui/design_tokens.dart';

class PendingApprovalScreen extends StatelessWidget {
  final String userName;
  final String userEmail;
  final String orgName;
  final String orgCode;

  const PendingApprovalScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.orgName,
    required this.orgCode,
  });

  Future<void> _handleSignOut(BuildContext context) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final teacherFile = File('${directory.path}/.logged_in_teacher_email');
      if (await teacherFile.exists()) {
        await teacherFile.delete();
      }
    } catch (_) {}

    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
        (route) => false,
      );
    }
  }

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
                : [AppColors.slate100, const Color(0xFFE2E8F0)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                
                // Pulsing Warning Icon
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.amber.withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.hourglass_empty_rounded,
                      size: 64,
                      color: AppColors.amber,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.xxl),

                Text(
                  'Pending Approval',
                  textAlign: TextAlign.center,
                  style: AppType.display(
                    context,
                    fontSize: 28,
                    weight: FontWeight.w700,
                    color: AppColors.textPrimary(isDark),
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                Text(
                  'Your registration request is currently under review by the Administrator.',
                  textAlign: TextAlign.center,
                  style: AppType.body(
                    context,
                    fontSize: 14.5,
                    color: AppColors.textSecondary(isDark),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: AppSpace.xxl),

                // Info Cards Box
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(context, 'User', userName, isDark),
                        const Divider(height: 24),
                        _buildInfoRow(context, 'Email', userEmail, isDark),
                        const Divider(height: 24),
                        _buildInfoRow(context, 'Organization', orgName, isDark),
                        const Divider(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoRow(context, 'Organization Code', orgCode, isDark),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: orgCode));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Code copied to clipboard!'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                ElevatedButton(
                  onPressed: () => _handleSignOut(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Back to Sign-In'),
                ),
                const SizedBox(height: AppSpace.md),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppType.body(
            context,
            fontSize: 10,
            weight: FontWeight.w700,
            color: isDark ? AppColors.indigoLight : AppColors.slate500,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppType.body(
            context,
            fontSize: 15,
            weight: FontWeight.w600,
            color: AppColors.textPrimary(isDark),
          ),
        ),
      ],
    );
  }
}
