import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/csv_export.dart';
import '../../data/models/attendance_event.dart';
import '../../providers/attendance_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  Future<void> _export(
    BuildContext context,
    List<AttendanceEvent> events,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    // iPads need an anchor for the share sheet.
    final box = context.findRenderObject() as RenderBox?;
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/campus_register_log.csv');
      await file.writeAsString(eventsToCsv(events), flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(attendanceProvider).requireValue;
    final scheme = Theme.of(context).colorScheme;
    final events = state.events;

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          Builder(
            builder: (context) => IconButton(
              tooltip: 'Export CSV',
              icon: const Icon(Icons.ios_share),
              onPressed: events.isEmpty ? null : () => _export(context, events),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          ListTile(
            leading: Icon(
              state.intact ? Icons.verified_outlined : Icons.gpp_bad_outlined,
              color: state.intact ? scheme.primary : scheme.error,
            ),
            title: Text(
              state.intact ? 'Hash chain intact' : 'Hash chain is broken',
            ),
            subtitle: Text('${events.length} attempts recorded'),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: events.length,
              itemBuilder: (context, i) {
                final index = events.length - 1 - i;
                final e = events[index];
                final local = e.time.toLocal().toString().substring(0, 19);
                return ListTile(
                  leading: Icon(
                    e.decision.isAccepted ? Icons.check_circle : Icons.block,
                    color: e.decision.isAccepted
                        ? scheme.primary
                        : scheme.error,
                  ),
                  title: Text(
                    '${e.type == AttendanceType.signIn ? 'Sign in' : 'Sign out'}'
                    ' · ${e.decision.name}',
                  ),
                  subtitle: Text(local),
                  trailing: Icon(
                    index < state.syncedCount
                        ? Icons.cloud_done_outlined
                        : Icons.schedule,
                    semanticLabel: index < state.syncedCount
                        ? 'Uploaded'
                        : 'Waiting to upload',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
