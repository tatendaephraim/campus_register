import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/attendance_provider.dart';
import 'admin_settings_screen.dart';
import 'data_log_screen.dart';

class AttendanceDashboard extends ConsumerStatefulWidget {
  const AttendanceDashboard({super.key});

  @override
  ConsumerState<AttendanceDashboard> createState() =>
      _AttendanceDashboardState();
}

class _AttendanceDashboardState extends ConsumerState<AttendanceDashboard> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(attendanceProvider.notifier).setUserName('Tatenda');
      ref.read(attendanceProvider.notifier).refreshLocation();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Campus Register',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('Admin Dashboard',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w300)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DataLogScreen(),
                ),
              );
            },
            tooltip: 'View Data Log',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminSettingsScreen(),
                ),
              );
            },
            tooltip: 'Admin Settings',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(attendanceProvider.notifier).refreshLocation(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildUserInfoCard(state, theme),
              const SizedBox(height: 16),
              _buildVenueSelectorCard(state, theme),
              const SizedBox(height: 16),
              _buildLocationStatusCard(state, theme),
              const SizedBox(height: 24),
              _buildActionButtons(state, theme),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 16),
                _buildErrorMessage(state.errorMessage!, theme),
              ],
              if (state.isAlreadyMarked) ...[
                const SizedBox(height: 16),
                _buildSuccessMessage(theme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfoCard(AttendanceState state, ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                state.userName?.substring(0, 1).toUpperCase() ?? 'A',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.userName ?? 'Admin User',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Administrator',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.admin_panel_settings,
              color: theme.colorScheme.primary,
              size: 32,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVenueSelectorCard(AttendanceState state, ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_city, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Select Class/Venue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: state.currentVenue?.id,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              isExpanded: true,
              items: state.availableVenues.map((venue) {
                return DropdownMenuItem(
                  value: venue.id,
                  child: Text(
                    venue.description != null
                        ? '${venue.name} - ${venue.description}'
                        : venue.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (venueId) {
                if (venueId != null) {
                  final venue =
                      state.availableVenues.firstWhere((v) => v.id == venueId);
                  ref.read(attendanceProvider.notifier).selectVenue(venue);
                }
              },
            ),
            if (state.currentVenue?.description != null) ...[
              const SizedBox(height: 8),
              Text(
                state.currentVenue!.description!,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationStatusCard(AttendanceState state, ThemeData theme) {
    final isAtVenue = state.isAtCampus;
    final statusColor = isAtVenue ? Colors.green : Colors.orange;
    final statusIcon =
        isAtVenue ? Icons.check_circle : Icons.location_searching;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isAtVenue ? Colors.green[50] : Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(statusIcon, size: 48, color: statusColor),
            const SizedBox(height: 12),
            Text(
              isAtVenue
                  ? 'You are at ${state.currentVenue?.name ?? "venue"}'
                  : 'Not at selected venue',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isAtVenue ? Colors.green[800] : Colors.orange[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Divider(color: isAtVenue ? Colors.green[200] : Colors.orange[200]),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoChip(
                  icon: Icons.straighten,
                  label: 'Distance',
                  value: state.distanceToVenue != null
                      ? '${state.distanceToVenue!.toStringAsFixed(0)}m'
                      : '--',
                  color: statusColor,
                ),
                _buildInfoChip(
                  icon: Icons.layers,
                  label: 'Floor',
                  value: '${state.currentFloor}',
                  color: statusColor,
                ),
                _buildInfoChip(
                  icon: Icons.height,
                  label: 'Altitude',
                  value: '${state.currentAltitude.toStringAsFixed(0)}m',
                  color: statusColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(AttendanceState state, ThemeData theme) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () =>
              ref.read(attendanceProvider.notifier).refreshLocation(),
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh Location'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: theme.colorScheme.primary,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.primary),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: state.isAtCampus && !state.isAlreadyMarked
              ? () => ref
                  .read(attendanceProvider.notifier)
                  .attemptAttendance('CHECK-IN')
              : null,
          icon: const Icon(Icons.fingerprint, size: 28),
          label: const Text(
            'Mark Attendance',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 64),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: state.isAtCampus && !state.isAlreadyMarked ? 4 : 0,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage(String message, ThemeData theme) {
    final isBiometricEnrollmentNeeded =
        message.contains('No biometrics enrolled') ||
            message.contains('not available');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Colors.red[900],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (isBiometricEnrollmentNeeded) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                // Show instructions
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Set Up Biometric Authentication'),
                    content: const Text(
                      'To use this app, you need to set up fingerprint or face unlock on your device.\n\n'
                      '1. Open device Settings\n'
                      '2. Go to Security & Privacy\n'
                      '3. Select Fingerprint or Face Unlock\n'
                      '4. Follow the setup instructions\n'
                      '5. Return to this app',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
              icon: Icon(Icons.settings, color: Colors.red[700]),
              label: Text(
                'How to set up biometrics',
                style: TextStyle(color: Colors.red[700]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuccessMessage(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: Colors.green[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Attendance marked successfully!',
              style: TextStyle(
                color: Colors.green[900],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
