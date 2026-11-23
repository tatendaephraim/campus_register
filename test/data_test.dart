import 'dart:convert';
import 'dart:io';

import 'package:campus_register/data/csv_export.dart';
import 'package:campus_register/data/local/attendance_store.dart';
import 'package:campus_register/data/models/attendance_event.dart';
import 'package:campus_register/data/models/student_profile.dart';
import 'package:campus_register/data/remote/google_sheets_api.dart';
import 'package:campus_register/data/repositories/attendance_repository.dart';
import 'package:campus_register/domain/attendance_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const profile = StudentProfile(
  studentId: 'S1',
  name: 'Ada, "A" Ńkó',
  deviceId: 'dev',
);

void main() {
  late Directory dir;
  final day = DateTime(2026, 11, 23, 9);

  setUp(() async => dir = await Directory.systemTemp.createTemp('cr_test'));
  tearDown(() => dir.delete(recursive: true));

  GoogleSheetsApi api(
    MockClientHandler handler, {
    String url = 'https://x/e',
  }) => GoogleSheetsApi(url: url, token: 't', client: MockClient(handler));

  Future<AttendanceRepository> open(GoogleSheetsApi api) async {
    final r = AttendanceRepository(AttendanceStore(dir), api);
    await r.load();
    if (r.profile == null) await r.enrol(profile);
    return r;
  }

  final offline = api((_) async => throw const SocketException('no network'));
  final ok = api((_) async => http.Response('{"ok":true}', 200));

  Future<void> add(
    AttendanceRepository r, {
    Decision decision = Decision.accepted,
  }) => r.record(
    type: r.nextType(day),
    decision: decision,
    at: day,
    distanceM: 12.34,
    accuracyM: 5,
  );

  group('hash chain', () {
    test('survives a reload and stays intact', () async {
      final r = await open(offline);
      await add(r);
      await add(r);
      final reloaded = await open(offline);
      expect(reloaded.events, hasLength(2));
      expect(reloaded.events[1].prevHash, reloaded.events[0].hash);
      expect(reloaded.isIntact, isTrue);
    });

    test('detects an edited entry', () async {
      final r = await open(offline);
      await add(r, decision: Decision.outsideCampus);
      await add(r);
      final log = File('${dir.path}/attendance.jsonl');
      await log.writeAsString(
        (await log.readAsString()).replaceFirst('outsideCampus', 'accepted'),
      );
      expect((await open(offline)).isIntact, isFalse);
    });

    test('detects a deleted entry', () async {
      final r = await open(offline);
      await add(r);
      await add(r);
      await add(r);
      final log = File('${dir.path}/attendance.jsonl');
      final lines = (await log.readAsLines())..removeAt(1);
      await log.writeAsString('${lines.join('\n')}\n');
      final events = await AttendanceStore(dir).loadEvents();
      expect(firstBrokenLink(events), 1);
    });
  });

  group('store', () {
    test('drops a torn final write and keeps appending', () async {
      final r = await open(offline);
      await add(r);
      await File(
        '${dir.path}/attendance.jsonl',
      ).writeAsString('{"deviceId":"de', mode: FileMode.append);
      final reloaded = await open(offline);
      await add(reloaded);
      final again = await open(offline);
      expect(again.events, hasLength(2));
      expect(again.isIntact, isTrue);
    });

    test('refuses to load a damaged log', () async {
      await File('${dir.path}/attendance.jsonl').writeAsString('garbage\n');
      await expectLater(
        AttendanceStore(dir).loadEvents(),
        throwsA(isA<CorruptLogException>()),
      );
    });

    test('cannot be enrolled twice', () async {
      final r = await open(offline);
      await expectLater(r.enrol(profile), throwsStateError);
    });
  });

  test('alternates in and out, ignores rejections, resets daily', () async {
    final r = await open(offline);
    expect(r.nextType(day), AttendanceType.signIn);
    await add(r, decision: Decision.outsideCampus);
    expect(r.nextType(day), AttendanceType.signIn);
    await add(r);
    expect(r.nextType(day), AttendanceType.signOut);
    expect(r.nextType(day.add(const Duration(days: 1))), AttendanceType.signIn);
    await add(r);
    expect(r.nextType(day), AttendanceType.signIn);
  });

  group('sync', () {
    test('keeps records offline and uploads each once, in order', () async {
      final r = await open(offline);
      await add(r);
      await add(r);
      expect((await r.sync()).status, SyncStatus.offline);
      expect(r.pendingCount, 2);

      final sent = <String>[];
      final online = await open(
        api((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['token'], 't');
          sent.add((body['event'] as Map)['seq'] as String);
          return http.Response('{"ok":true}', 200);
        }),
      );
      await Future.wait([online.sync(), online.sync()]);
      expect(sent, ['0', '1']);
      expect((await open(ok)).pendingCount, 0);
    });

    test('follows the Apps Script redirect with a GET', () async {
      final methods = <String>[];
      final r = await open(
        api((request) async {
          methods.add(request.method);
          return request.method == 'POST'
              ? http.Response('', 302, headers: {'location': 'https://x/out'})
              : http.Response('{"ok":true}', 200);
        }),
      );
      await add(r);
      expect((await r.sync()).status, SyncStatus.ok);
      expect(methods, ['POST', 'GET']);
    });

    test('does not mistake HTTP 200 for success', () async {
      for (final body in ['{"ok":false,"error":"no"}', '<html>', '[]']) {
        final r = await open(api((_) async => http.Response(body, 200)));
        if (r.events.isEmpty) await add(r);
        expect((await r.sync()).status, SyncStatus.rejected, reason: body);
        expect(r.pendingCount, 1);
      }
    });

    test('stays local without a server', () async {
      final r = await open(api((_) async => fail('called'), url: ''));
      await add(r);
      expect((await r.sync()).status, SyncStatus.notConfigured);
    });
  });

  test('CSV quotes fields and disarms formulas', () {
    AttendanceEvent named(String name) => AttendanceEvent.create(
      deviceId: 'd',
      seq: 0,
      studentId: 'S1',
      name: name,
      type: AttendanceType.signIn,
      decision: Decision.accepted,
      at: day,
      prevHash: AttendanceEvent.genesisHash,
    );
    final csv = eventsToCsv([named('Ada, "A"'), named('=1+1')]);
    expect(csv, contains(',"Ada, ""A""",'));
    expect(csv, contains(",'=1+1,"));
    expect(csv.split('\r\n').first.split(','), hasLength(13));
  });

  // Runs the real server script, so a drift between the Dart and Apps Script
  // hash encodings fails here rather than in the field.
  test('server verifies hashes produced by the app', () async {
    final r = await open(offline);
    for (var i = 0; i < 3; i++) {
      await add(r);
    }
    final result = await Process.run('node', [
      'server/test_harness.js',
      '${dir.path}/attendance.jsonl',
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  }, skip: _hasNode() ? false : 'Node.js is not installed');
}

bool _hasNode() {
  try {
    return Process.runSync('node', ['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}
