import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';
import '../data/local/attendance_store.dart';
import '../data/models/attendance_event.dart';
import '../data/models/student_profile.dart';
import '../data/remote/google_sheets_api.dart';
import '../data/repositories/attendance_repository.dart';
import '../domain/attendance_policy.dart';
import '../services/biometric_service.dart';
import '../services/location_service.dart';

final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final policyProvider = Provider<AttendancePolicy>((ref) => AppConfig.policy);

final locationServiceProvider = Provider((ref) => LocationService());

final biometricServiceProvider = Provider((ref) => BiometricService());

final repositoryProvider = FutureProvider<AttendanceRepository>((ref) async {
  final repository = AttendanceRepository(
    AttendanceStore(await getApplicationSupportDirectory()),
    GoogleSheetsApi(url: AppConfig.syncUrl, token: AppConfig.syncToken),
  );
  await repository.load();
  return repository;
});

final attendanceProvider =
    AsyncNotifierProvider<AttendanceNotifier, AttendanceState>(
      AttendanceNotifier.new,
    );

class Notice {
  const Notice(this.text, {this.isError = false});
  final String text;
  final bool isError;
}

class AttendanceState {
  const AttendanceState({
    required this.profile,
    required this.events,
    required this.syncedCount,
    required this.intact,
    required this.nextType,
    this.check,
    this.accuracyM,
    this.problem,
    this.locating = false,
    this.signing = false,
    this.notice,
    this.syncNote = '',
  });

  final StudentProfile? profile;
  final List<AttendanceEvent> events;
  final int syncedCount;
  final bool intact;
  final AttendanceType nextType;

  /// Latest location verdict, for guidance only. Signing always re-checks.
  final PolicyResult? check;
  final double? accuracyM;
  final LocationProblem? problem;

  final bool locating;
  final bool signing;
  final Notice? notice;
  final String syncNote;

  int get pendingCount => events.length - syncedCount;
}

class AttendanceNotifier extends AsyncNotifier<AttendanceState> {
  late AttendanceRepository _repository;

  PolicyResult? _check;
  double? _accuracyM;
  LocationProblem? _problem;
  bool _locating = false;
  bool _signing = false;
  Notice? _notice;
  String _syncNote = '';

  @override
  Future<AttendanceState> build() async {
    _repository = await ref.watch(repositoryProvider.future);
    return _snapshot();
  }

  AttendanceState _snapshot() => AttendanceState(
    profile: _repository.profile,
    events: _repository.events,
    syncedCount: _repository.syncedCount,
    intact: _repository.isIntact,
    nextType: _repository.nextType(ref.read(clockProvider)()),
    check: _check,
    accuracyM: _accuracyM,
    problem: _problem,
    locating: _locating,
    signing: _signing,
    notice: _notice,
    syncNote: _syncNote,
  );

  void _publish() {
    if (ref.mounted) state = AsyncData(_snapshot());
  }

  Future<void> enrol({required String studentId, required String name}) async {
    await _repository.enrol(
      StudentProfile.enrol(studentId: studentId, name: name),
    );
    _publish();
  }

  Future<void> refresh() async {
    if (_locating || _signing) return;
    _locating = true;
    _publish();
    try {
      await _locate();
    } finally {
      _locating = false;
      _publish();
    }
    await sync();
  }

  Future<void> sync() async {
    final result = await _repository.sync();
    _syncNote = switch (result.status) {
      SyncStatus.ok => '',
      SyncStatus.notConfigured => 'No server configured; records stay here.',
      SyncStatus.offline => 'Server unreachable (${result.detail}).',
      SyncStatus.rejected => 'Server refused a record: ${result.detail}.',
    };
    _publish();
  }

  /// Runs the whole decision and logs its outcome, whether accepted or not.
  Future<void> sign() async {
    if (_locating || _signing || _repository.profile == null) return;
    _signing = true;
    _notice = null;
    _publish();
    try {
      await _sign();
    } catch (e) {
      _notice = Notice('The attempt could not be saved: $e', isError: true);
    } finally {
      _signing = false;
      _publish();
    }
    // The record is already safe on disk, so the user need not wait for this.
    unawaited(sync());
  }

  Future<void> _sign() async {
    if (!_repository.isIntact) {
      _notice = const Notice(
        'The local log has been altered, so signing is disabled.',
        isError: true,
      );
      return;
    }
    final now = ref.read(clockProvider);
    final type = _repository.nextType(now());

    final locationTimer = Stopwatch()..start();
    final reading = await _locate();
    locationTimer.stop();
    var result = _check!;

    final biometricTimer = Stopwatch();
    if (result.decision.isAccepted) {
      biometricTimer.start();
      final outcome = await ref.read(biometricServiceProvider).authenticate();
      biometricTimer.stop();
      result = switch (outcome) {
        // The prompt can stay open indefinitely, so the fix must still be
        // fresh when the biometric succeeds.
        BiometricOutcome.verified => _evaluate(reading),
        BiometricOutcome.failed => PolicyResult(
          Decision.biometricFailed,
          distanceM: result.distanceM,
        ),
        BiometricOutcome.unavailable => PolicyResult(
          Decision.biometricUnavailable,
          distanceM: result.distanceM,
        ),
      };
    }

    final decision = result.decision;
    await _repository.record(
      type: type,
      decision: decision,
      at: now(),
      distanceM: result.distanceM,
      accuracyM: reading.position?.accuracyM,
      locationMs: locationTimer.elapsedMilliseconds,
      biometricMs: biometricTimer.elapsedMilliseconds,
    );
    _notice = Notice(
      reading.problem?.message ?? decision.message,
      isError: !decision.isAccepted,
    );
  }

  Future<LocationReading> _locate() async {
    final reading = await ref.read(locationServiceProvider).read();
    _accuracyM = reading.position?.accuracyM;
    _problem = reading.problem;
    _check = _evaluate(reading);
    return reading;
  }

  PolicyResult _evaluate(LocationReading reading) {
    final events = _repository.events;
    return ref
        .read(policyProvider)
        .evaluate(
          position: reading.position,
          now: ref.read(clockProvider)(),
          lastEventAt: events.isEmpty ? null : events.last.time,
        );
  }
}
