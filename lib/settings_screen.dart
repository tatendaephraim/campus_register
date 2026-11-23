import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_helper.dart';
import 'ui/design_tokens.dart';
import 'services/theme_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _testingConnection = false;
  String _connectionStatus = 'Idle';
  Color _statusColor = Colors.grey;

  Future<void> _testSupabaseConnection() async {
    setState(() {
      _testingConnection = true;
      _connectionStatus = 'Testing Connection...';
      _statusColor = Colors.blue;
    });

    try {
      // Execute a quick select request to verify API connection.
      await Supabase.instance.client.from('teachers').select('id').limit(1);
      
      setState(() {
        _connectionStatus = 'Supabase Cloud Connected';
        _statusColor = Colors.green;
      });
    } catch (e) {
      setState(() {
        _connectionStatus = 'Connection Failed: ${e.toString().split('\n').first}';
        _statusColor = Colors.red;
      });
    } finally {
      setState(() {
        _testingConnection = false;
      });
    }
  }

  Future<void> _clearOfflineCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear offline database cache?', style: AppType.display(context, fontSize: 17, weight: FontWeight.w600)),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xlR),
        content: Text(
          'This will delete all courses, venue configurations, registered student lists, and offline attendance records from this device.\n\nMake sure all data is synced with Supabase or Google Sheets before proceeding!',
          style: AppType.body(context, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear database'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final db = await DatabaseHelper.instance.database;
        final batch = db.batch();
        batch.delete('teachers');
        batch.delete('courses');
        batch.delete('timetable_slots');
        batch.delete('students');
        batch.delete('attendance_records');
        batch.delete('venues');
        await batch.commit(noResult: true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offline database cache cleared successfully.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error clearing database: $e'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
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
            // Connection Diagnostics Category
            _buildCategoryHeader(context, 'SYSTEM DIAGNOSTICS & SYNC'),
            const SizedBox(height: AppSpace.sm),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.sky.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.cloud_sync_rounded, color: AppColors.sky),
                        ),
                        const SizedBox(width: AppSpace.md + 2),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cloud sync status',
                                style: AppType.display(context, fontSize: 15.5, weight: FontWeight.w600, color: AppColors.textPrimary(isDark)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _connectionStatus,
                                style: AppType.body(context, color: _statusColor, weight: FontWeight.w600, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.lg),
                    ElevatedButton.icon(
                      onPressed: _testingConnection ? null : _testSupabaseConnection,
                      icon: _testingConnection
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(_testingConnection ? 'Testing…' : 'Test connection'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.smR),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpace.xxl),

            // Storage Management Category
            _buildCategoryHeader(context, 'STORAGE & RESET'),
            const SizedBox(height: AppSpace.sm),
            Card(
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: AppRadius.lgR),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_sweep_rounded, color: AppColors.danger),
                ),
                title: Text(
                  'Clear offline database',
                  style: AppType.display(context, fontSize: 15, weight: FontWeight.w600, color: AppColors.danger),
                ),
                subtitle: Text('Purge all offline cached records from device storage.', style: AppType.body(context, fontSize: 12.5, color: AppColors.textSecondary(isDark))),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: _clearOfflineCache,
              ),
            ),

            const SizedBox(height: AppSpace.xxl),

            // Appearance & Theme Category
            ValueListenableBuilder<ThemeSettings>(
              valueListenable: ThemeService.instance.settingsNotifier,
              builder: (context, settings, child) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCategoryHeader(context, 'APPEARANCE & THEME'),
                    const SizedBox(height: AppSpace.sm),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpace.md, horizontal: AppSpace.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Theme Mode',
                              style: AppType.display(context, fontSize: 14.5, weight: FontWeight.w600, color: AppColors.textPrimary(isDark)),
                            ),
                            const SizedBox(height: AppSpace.md),
                            Row(
                              children: [
                                Expanded(child: _buildThemeModeCard(context, ThemeMode.light, Icons.light_mode_rounded, 'Light', settings.themeMode)),
                                const SizedBox(width: AppSpace.sm),
                                Expanded(child: _buildThemeModeCard(context, ThemeMode.dark, Icons.dark_mode_rounded, 'Dark', settings.themeMode)),
                                const SizedBox(width: AppSpace.sm),
                                Expanded(child: _buildThemeModeCard(context, ThemeMode.system, Icons.settings_brightness_rounded, 'System', settings.themeMode)),
                              ],
                            ),
                            const SizedBox(height: AppSpace.xl),
                            Text(
                              'Accent Color',
                              style: AppType.display(context, fontSize: 14.5, weight: FontWeight.w600, color: AppColors.textPrimary(isDark)),
                            ),
                            const SizedBox(height: AppSpace.md),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: AppThemeColor.values.map((colorEnum) {
                                return _buildThemeColorCircle(context, colorEnum, settings.themeColor);
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.xxl),
                    
                    _buildCategoryHeader(context, 'APP CONFIGURATION'),
                    const SizedBox(height: AppSpace.sm),
                    const Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(Icons.vibration_rounded),
                            title: Text('Haptic feedback'),
                            subtitle: Text('Vibrate on successful check-in scan'),
                            trailing: Icon(Icons.check_rounded, color: AppColors.success),
                          ),
                          Divider(height: 1),
                          ListTile(
                            leading: Icon(Icons.location_on_outlined),
                            title: Text('GPS precision'),
                            subtitle: Text('High accuracy mode for 3D checking'),
                            trailing: Icon(Icons.check_rounded, color: AppColors.success),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpace.sm),
      child: Text(
        title,
        style: AppType.body(
          context,
          fontSize: 11,
          weight: FontWeight.w700,
          color: AppColors.slate500,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildThemeModeCard(
    BuildContext context,
    ThemeMode mode,
    IconData icon,
    String label,
    ThemeMode currentMode,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = mode == currentMode;
    
    return InkWell(
      onTap: () => ThemeService.instance.updateThemeMode(mode),
      borderRadius: AppRadius.mdR,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.08)
              : (isDark ? AppColors.slate900.withValues(alpha: 0.4) : AppColors.slate100),
          borderRadius: AppRadius.mdR,
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : AppColors.border(isDark),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? theme.colorScheme.primary : AppColors.textSecondary(isDark),
              size: 20,
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              label,
              style: AppType.body(
                context,
                fontSize: 12,
                weight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? theme.colorScheme.primary : AppColors.textSecondary(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeColorCircle(
    BuildContext context,
    AppThemeColor colorEnum,
    AppThemeColor currentColor,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = colorEnum == currentColor;
    
    Color color;
    String name;
    switch (colorEnum) {
      case AppThemeColor.indigo:
        color = const Color(0xFF6366F1);
        name = 'Indigo';
        break;
      case AppThemeColor.rose:
        color = const Color(0xFFF43F5E);
        name = 'Rose';
        break;
      case AppThemeColor.teal:
        color = const Color(0xFF14B8A6);
        name = 'Teal';
        break;
      case AppThemeColor.amber:
        color = const Color(0xFFF59E0B);
        name = 'Amber';
        break;
      case AppThemeColor.obsidian:
        color = const Color(0xFF64748B);
        name = 'Obsidian';
        break;
    }

    return Column(
      children: [
        GestureDetector(
          onTap: () => ThemeService.instance.updateThemeColor(colorEnum),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black)
                    : Colors.transparent,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ],
            ),
            child: isSelected
                ? const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 20,
                  )
                : null,
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          name,
          style: AppType.body(
            context,
            fontSize: 11,
            weight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? theme.colorScheme.primary : AppColors.textSecondary(isDark),
          ),
        ),
      ],
    );
  }
}
