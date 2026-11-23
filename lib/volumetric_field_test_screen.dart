import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'domain/volumetric_check.dart';
import 'services/altitude_service.dart';
import 'services/attempt_log.dart';
import 'services/volumetric_verifier.dart';
import 'ui/design_tokens.dart';
import 'venue.dart';

/// Records labelled 3D test cases at a venue. The tester states where they
/// really are, the app decides independently, and both are logged so that error
/// rates can be measured. It never creates attendance.
class VolumetricFieldTestScreen extends StatefulWidget {
  const VolumetricFieldTestScreen({super.key, required this.venue});

  final Venue venue;

  @override
  State<VolumetricFieldTestScreen> createState() =>
      _VolumetricFieldTestScreenState();
}

class _VolumetricFieldTestScreenState extends State<VolumetricFieldTestScreen> {
  static const _cases = <String, String>{
    'inside': 'Inside the room',
    'floor_above': 'One floor above',
    'floors_above_2': 'Two or more floors above',
    'floor_below': 'One floor below',
    'next_room': 'Next room, same floor',
    'outdoors': 'Outside the building',
  };

  final _note = TextEditingController();
  String _expected = 'inside';
  bool _sampling = false;
  String? _error;
  VolumetricReading? _reading;
  List<Attempt> _attempts = [];

  @override
  void initState() {
    super.initState();
    AltitudeService.instance.start();
    _load();
  }

  @override
  void dispose() {
    AltitudeService.instance.stop();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final all = await AttemptLog.instance.load();
    if (!mounted) return;
    setState(() {
      _attempts = all
          .where(
            (a) => a.source == 'field-test' && a.venue == widget.venue.name,
          )
          .toList();
    });
  }

  Future<void> _sample() async {
    setState(() {
      _sampling = true;
      _error = null;
    });
    try {
      final reading = await VolumetricVerifier().verify(
        widget.venue,
        source: 'field-test',
        allowCircle: true,
        expected: _expected,
        note: _note.text.trim(),
      );
      if (mounted) setState(() => _reading = reading);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _sampling = false);
    }
  }

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await AttemptLog.instance.file();
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: 'text/csv')]),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final band = HeightBand.forVenue(widget.venue);

    return Scaffold(
      appBar: AppBar(
        title: const Text('3D field test'),
        actions: [
          IconButton(
            tooltip: 'Export CSV',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: _attempts.isEmpty ? null : _export,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.xl),
        children: [
          Text(
            widget.venue.name,
            style: AppType.display(
              context,
              fontSize: 22,
              weight: FontWeight.w700,
              color: AppColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            'Floor ${widget.venue.altitude.toStringAsFixed(1)} m, '
            'band -${band.below.toStringAsFixed(0)} to '
            '+${band.above.toStringAsFixed(0)} m',
            style: AppType.data(
              context,
              fontSize: 12.5,
              color: AppColors.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          Text(
            'Where are you really standing?',
            style: AppType.body(
              context,
              fontSize: 13,
              weight: FontWeight.w700,
              color: AppColors.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.xs,
            children: [
              for (final c in _cases.entries)
                ChoiceChip(
                  label: Text(c.value),
                  selected: _expected == c.key,
                  onSelected: (_) => setState(() => _expected = c.key),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          TextField(
            controller: _note,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Note (phone model, weather, position)',
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          ElevatedButton.icon(
            onPressed: _sampling ? null : _sample,
            icon: _sampling
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.layers_rounded),
            label: Text(_sampling ? 'Measuring…' : 'Record test case'),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.md),
            Text(_error!, style: const TextStyle(color: AppColors.dangerDark)),
          ],
          if (_reading != null) ...[
            const SizedBox(height: AppSpace.lg),
            _ReadingCard(reading: _reading!, isDark: isDark),
          ],
          const SizedBox(height: AppSpace.lg),
          _SummaryCard(attempts: _attempts, cases: _cases, isDark: isDark),
        ],
      ),
    );
  }
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({required this.reading, required this.isDark});

  final VolumetricReading reading;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final r = reading.result;
    final color = r.decision.isInside
        ? AppColors.successDark
        : AppColors.dangerDark;
    String m(double? v) => v == null ? '–' : '${v.toStringAsFixed(1)} m';
    final rows = <(String, String)>[
      ('Height above floor', m(r.heightM)),
      ('Uncertainty (1σ)', m(r.sigmaM)),
      (
        'Probability in band',
        r.probability == null
            ? '–'
            : '${(r.probability! * 100).toStringAsFixed(0)}%',
      ),
      (
        'GPS altitude',
        '${m(reading.position.altitude)} ± '
            '${m(reading.position.altitudeAccuracy)}',
      ),
      (
        'Barometer',
        reading.pressureHpa == null
            ? 'not available'
            : '${reading.pressureHpa!.toStringAsFixed(2)} hPa',
      ),
      ('Horizontal accuracy', m(reading.position.accuracy)),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r.decision.message,
              style: AppType.display(context, fontSize: 15, color: color),
            ),
            const SizedBox(height: AppSpace.md),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: AppType.body(
                          context,
                          fontSize: 12.5,
                          color: AppColors.textSecondary(isDark),
                        ),
                      ),
                    ),
                    Text(
                      value,
                      style: AppType.data(
                        context,
                        fontSize: 12.5,
                        color: AppColors.textPrimary(isDark),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.attempts,
    required this.cases,
    required this.isDark,
  });

  final List<Attempt> attempts;
  final Map<String, String> cases;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final style = AppType.data(
      context,
      fontSize: 12.5,
      color: AppColors.textPrimary(isDark),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Results: ${attempts.length} test cases',
              style: AppType.display(
                context,
                fontSize: 15,
                color: AppColors.textPrimary(isDark),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            for (final c in cases.entries)
              if (attempts.where((a) => a.expected == c.key).toList()
                  case final rows when rows.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(child: Text(c.value, style: style)),
                      Text(
                        '${rows.where((a) => a.accepted).length} of '
                        '${rows.length} accepted',
                        style: style,
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
