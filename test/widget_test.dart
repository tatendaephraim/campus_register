import 'package:campus_register/data/local/attendance_store.dart';
import 'package:campus_register/data/models/attendance_event.dart';
import 'package:campus_register/data/models/student_profile.dart';
import 'package:campus_register/data/remote/google_sheets_api.dart';
import 'package:campus_register/data/repositories/attendance_repository.dart';
import 'package:campus_register/domain/attendance_policy.dart';
import 'package:campus_register/main.dart';
import 'package:campus_register/providers/attendance_provider.dart';
import 'package:campus_register/services/biometric_service.dart';
import 'package:campus_register/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget tests run in fake time, where real file access never completes.
class MemoryStore implements AttendanceStore {
  StudentProfile? profile;
  final events = <AttendanceEvent>[];
  int synced = 0;

  @override
  Future<StudentProfile?> loadProfile() async => profile;
  @override
  Future<void> saveProfile(StudentProfile p) async => profile = p;
  @override
  Future<List<AttendanceEvent>> loadEvents() async => [...events];
  @override
  Future<void> append(AttendanceEvent e) async => events.add(e);
  @override
  Future<int> loadSyncedCount() async => synced;
  @override
  Future<void> saveSyncedCount(int count) async => synced = count;
}

class FakeLocation implements LocationService {
  double latitude = 0;
  int reads = 0;
  @override
  Future<LocationReading> read() async => _read();

  LocationReading _read() {
    reads++;
    return LocationReading.fix(
      PositionSample(
        latitude: latitude,
        longitude: 0,
        accuracyM: 5,
        timestamp: clock,
      ),
    );
  }
}

class FakeBiometric implements BiometricService {
  BiometricOutcome outcome = BiometricOutcome.verified;
  Duration delay = Duration.zero;
  int prompts = 0;
  @override
  Future<BiometricOutcome> authenticate() async {
    prompts++;
    clock = clock.add(delay);
    return outcome;
  }
}

DateTime clock = DateTime(2026, 11, 23, 9);

void main() {
  late MemoryStore store;
  late FakeLocation location;
  late FakeBiometric biometric;

  setUp(() {
    clock = DateTime(2026, 11, 23, 9);
    store = MemoryStore()
      ..profile = const StudentProfile(
        studentId: 'S1',
        name: 'Ada',
        deviceId: 'd',
      );
    location = FakeLocation();
    biometric = FakeBiometric();
  });

  Future<void> start(WidgetTester tester, {Object? loadError}) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          clockProvider.overrideWithValue(() => clock),
          policyProvider.overrideWithValue(
            const AttendancePolicy(latitude: 0, longitude: 0, radiusM: 100),
          ),
          locationServiceProvider.overrideWithValue(location),
          biometricServiceProvider.overrideWithValue(biometric),
          repositoryProvider.overrideWith((ref) async {
            if (loadError != null) throw loadError;
            final r = AttendanceRepository(store, GoogleSheetsApi(url: ''));
            await r.load();
            return r;
          }),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> sign(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.fingerprint));
    await tester.pumpAndSettle();
  }

  testWidgets('enrols, then shows the dashboard', (tester) async {
    store.profile = null;
    await start(tester);
    await tester.enterText(find.byKey(const Key('studentId')), ' r2001 ');
    await tester.enterText(find.byKey(const Key('name')), 'Grace Hopper');
    await tester.tap(find.text('Enrol'));
    await tester.pumpAndSettle();
    expect(store.profile, isNull, reason: 'consent is required');

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enrol'));
    await tester.pumpAndSettle();
    expect(store.profile!.studentId, 'R2001');
    expect(store.profile!.deviceId, hasLength(32));
    expect(find.text('Grace Hopper'), findsOneWidget);
  });

  testWidgets('signs in, then offers sign out', (tester) async {
    await start(tester);
    expect(find.text('You are on campus'), findsOneWidget);
    await sign(tester);
    expect(store.events.single.decision, Decision.accepted);
    expect(find.text('Verify and sign out'), findsOneWidget);
    expect(find.text('1 saved, waiting to upload'), findsOneWidget);
  });

  testWidgets('re-checks position at signing, not at launch', (tester) async {
    await start(tester);
    location.latitude = 1; // Left campus after the card turned green.
    await sign(tester);
    expect(store.events.single.decision, Decision.outsideCampus);
    expect(biometric.prompts, 0);
  });

  testWidgets('records a failed biometric', (tester) async {
    biometric.outcome = BiometricOutcome.failed;
    await start(tester);
    await sign(tester);
    expect(store.events.single.decision, Decision.biometricFailed);
    expect(find.text('Verify and sign in'), findsOneWidget);
  });

  testWidgets('a prompt left open makes the fix stale', (tester) async {
    biometric.delay = const Duration(minutes: 2);
    await start(tester);
    await sign(tester);
    expect(store.events.single.decision, Decision.staleFix);
  });

  testWidgets('an old error clears after a success', (tester) async {
    biometric.outcome = BiometricOutcome.failed;
    await start(tester);
    await sign(tester);
    expect(find.text(Decision.biometricFailed.message), findsOneWidget);
    biometric.outcome = BiometricOutcome.verified;
    await sign(tester);
    expect(find.text(Decision.biometricFailed.message), findsNothing);
    expect(find.text(Decision.accepted.message), findsOneWidget);
  });

  testWidgets('refreshes after backgrounding, not after a system dialog', (
    tester,
  ) async {
    await start(tester);
    expect(location.reads, 1);
    Future<void> go(List<AppLifecycleState> states) async {
      for (final s in states) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pumpAndSettle();
    }

    const dialog = [AppLifecycleState.inactive, AppLifecycleState.resumed];
    await go(dialog);
    expect(location.reads, 1);
    await go([
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      ...dialog,
    ]);
    expect(location.reads, 2);
  });

  testWidgets('history lists attempts', (tester) async {
    await start(tester);
    await sign(tester);
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    expect(find.text('Hash chain intact'), findsOneWidget);
    expect(find.text('Sign in · accepted'), findsOneWidget);
  });

  testWidgets('blocks signing when the log is damaged', (tester) async {
    await start(tester, loadError: const CorruptLogException(3));
    expect(find.textContaining('unreadable at line 3'), findsOneWidget);
    expect(find.byIcon(Icons.fingerprint), findsNothing);
  });
}
