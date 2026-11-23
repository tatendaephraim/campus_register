import '../../domain/attendance_policy.dart';
import '../local/attendance_store.dart';
import '../models/attendance_event.dart';
import '../models/student_profile.dart';
import '../remote/google_sheets_api.dart';

class AttendanceRepository {
  AttendanceRepository(this._store, this._api);

  final AttendanceStore _store;
  final GoogleSheetsApi _api;

  StudentProfile? _profile;
  List<AttendanceEvent> _events = [];
  int _synced = 0;
  Future<SyncResult>? _syncing;

  StudentProfile? get profile => _profile;
  List<AttendanceEvent> get events => List.unmodifiable(_events);
  int get syncedCount => _synced;
  int get pendingCount => _events.length - _synced;
  bool get isIntact => firstBrokenLink(_events) == null;

  Future<void> load() async {
    _profile = await _store.loadProfile();
    _events = await _store.loadEvents();
    _synced = (await _store.loadSyncedCount()).clamp(0, _events.length);
  }

  Future<void> enrol(StudentProfile profile) async {
    if (_profile != null) throw StateError('Device is already enrolled');
    await _store.saveProfile(profile);
    _profile = profile;
  }

  /// The action that comes next today: sign in, then out, alternating.
  AttendanceType nextType(DateTime now) {
    final today = now.toLocal();
    for (final e in _events.reversed) {
      if (!e.decision.isAccepted) continue;
      final t = e.time.toLocal();
      final sameDay =
          t.year == today.year && t.month == today.month && t.day == today.day;
      return sameDay && e.type == AttendanceType.signIn
          ? AttendanceType.signOut
          : AttendanceType.signIn;
    }
    return AttendanceType.signIn;
  }

  /// Writes durably to disk before returning. Never touches the network.
  Future<AttendanceEvent> record({
    required AttendanceType type,
    required Decision decision,
    required DateTime at,
    double? distanceM,
    double? accuracyM,
    int locationMs = 0,
    int biometricMs = 0,
  }) async {
    final profile = _profile;
    if (profile == null) throw StateError('Device is not enrolled');
    final event = AttendanceEvent.create(
      deviceId: profile.deviceId,
      seq: _events.length,
      studentId: profile.studentId,
      name: profile.name,
      type: type,
      decision: decision,
      at: at,
      distanceM: distanceM,
      accuracyM: accuracyM,
      locationMs: locationMs,
      biometricMs: biometricMs,
      prevHash: _events.isEmpty
          ? AttendanceEvent.genesisHash
          : _events.last.hash,
    );
    await _store.append(event);
    _events = [..._events, event];
    return event;
  }

  /// Uploads pending events in order, stopping at the first failure. Concurrent
  /// calls share one run.
  Future<SyncResult> sync() =>
      _syncing ??= _sync().whenComplete(() => _syncing = null);

  Future<SyncResult> _sync() async {
    if (!_api.isConfigured) return const SyncResult(SyncStatus.notConfigured);
    while (_synced < _events.length) {
      final result = await _api.send(_events[_synced]);
      if (result.status != SyncStatus.ok) return result;
      await _store.saveSyncedCount(_synced + 1);
      _synced++;
    }
    return const SyncResult(SyncStatus.ok);
  }
}
