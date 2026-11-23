import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../data/models/attendance_event.dart';
import '../../domain/attendance_policy.dart';
import '../../providers/attendance_provider.dart';
import '../history/history_screen.dart';

class AttendanceDashboard extends ConsumerStatefulWidget {
  const AttendanceDashboard({super.key});

  @override
  ConsumerState<AttendanceDashboard> createState() =>
      _AttendanceDashboardState();
}

class _AttendanceDashboardState extends ConsumerState<AttendanceDashboard> {
  late final AppLifecycleListener _lifecycle;
  bool _wasHidden = false;

  @override
  void initState() {
    super.initState();
    // Closing a system dialog also resumes the app. Refreshing then would show
    // the location dialog again as soon as the user declined it.
    _lifecycle = AppLifecycleListener(
      onHide: () => _wasHidden = true,
      onResume: () {
        if (!_wasHidden) return;
        _wasHidden = false;
        _refresh();
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (mounted) await ref.read(attendanceProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceProvider).requireValue;
    final scheme = Theme.of(context).colorScheme;
    final busy = state.locating || state.signing;
    final signingIn = state.nextType == AttendanceType.signIn;
    final notice = state.notice;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Register'),
        actions: [
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                state.profile!.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text('${state.profile!.studentId} · ${AppConfig.campusName}'),
              const SizedBox(height: 24),
              _LocationCard(state: state, onRefresh: busy ? null : _refresh),
              const SizedBox(height: 16),
              FilledButton.icon(
                // The card is only guidance. Signing takes its own fresh fix,
                // so the button does not depend on an old verdict.
                onPressed: busy || !state.intact
                    ? null
                    : () => ref.read(attendanceProvider.notifier).sign(),
                icon: state.signing
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.fingerprint),
                label: Text(
                  state.signing
                      ? 'Checking…'
                      : signingIn
                      ? 'Verify and sign in'
                      : 'Verify and sign out',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
              ),
              if (!state.intact) ...[
                const SizedBox(height: 16),
                Text(
                  'The local log has been altered, so signing is disabled.',
                  style: TextStyle(color: scheme.error),
                ),
              ],
              if (notice != null) ...[
                const SizedBox(height: 16),
                Text(
                  notice.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: notice.isError ? scheme.error : scheme.primary,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  state.pendingCount == 0
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_upload_outlined,
                ),
                title: Text(
                  state.pendingCount == 0
                      ? 'Nothing waiting to upload'
                      : '${state.pendingCount} saved, waiting to upload',
                ),
                subtitle: state.syncNote.isEmpty ? null : Text(state.syncNote),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.state, required this.onRefresh});

  final AttendanceState state;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final check = state.check;
    final onCampus = check?.decision.isAccepted ?? false;
    final accuracy = state.accuracyM;
    final distance = check?.distanceM;

    return Card(
      color: onCampus ? scheme.primaryContainer : scheme.surfaceContainerHigh,
      child: ListTile(
        leading: Icon(onCampus ? Icons.location_on : Icons.location_searching),
        title: Text(
          state.locating || check == null
              ? 'Finding your position…'
              : onCampus
              ? 'You are on campus'
              : check.decision == Decision.noPosition
              ? state.problem?.message ?? check.decision.message
              : check.decision.message,
        ),
        subtitle: distance == null || accuracy == null
            ? null
            : Text(
                '${distance.round()} m from centre, '
                'accurate to ${accuracy.round()} m',
              ),
        trailing: IconButton(
          tooltip: 'Check again',
          icon: const Icon(Icons.refresh),
          onPressed: onRefresh,
        ),
      ),
    );
  }
}
