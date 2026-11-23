import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/attendance_provider.dart';

class AttendanceDashboard extends ConsumerWidget {
  const AttendanceDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(attendanceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Campus Register')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Card(
              color: state.isAtCampus ? Colors.green[50] : Colors.red[50],
              child: ListTile(
                leading: Icon(
                  state.isAtCampus ? Icons.location_on : Icons.warning,
                  color: state.isAtCampus ? Colors.green : Colors.red,
                ),
                title: Text(
                  state.isAtCampus ? 'You are on Campus' : 'Outside Campus Boundaries',
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: state.isAtCampus && !state.isAlreadyMarked
                  ? () => ref.read(attendanceProvider.notifier).attemptAttendance('Tatenda', 'IN')
                  : null,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Verify Fingerprint & Sign'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(state.errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}