import 'dart:convert';
import 'dart:io';

import 'package:campus_register/attendance_record.dart';
import 'package:campus_register/check_in_repository.dart';
import 'package:campus_register/database_helper.dart';
import 'package:campus_register/services/attempt_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A stand-in for the attendance table. No test contacts a real server.
class FakeServer {
  bool online = true;
  bool loseReplies = false;
  int nextId = 1;
  final rows = <Map<String, dynamic>>[];
  final patched = <String>[];

  late final client = SupabaseClient(
    'http://localhost',
    'test-key',
    httpClient: MockClient(_handle),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  Future<http.Response> _handle(http.Request r) async {
    if (!online) throw const SocketException('offline');
    http.Response ok(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
      request: r,
    );
    final q = r.url.queryParameters;
    switch (r.method) {
      case 'POST':
        final row = {
          ...jsonDecode(r.body) as Map<String, dynamic>,
          'id': nextId++,
        };
        rows.add(row);
        if (loseReplies) throw const SocketException('reply lost');
        return ok(row);
      case 'PATCH':
        final id = q['id']!.replaceFirst('eq.', '');
        patched.add(id);
        for (final row in rows.where((x) => '${x['id']}' == id)) {
          row.addAll(jsonDecode(r.body) as Map<String, dynamic>);
        }
        return ok(<Object>[]);
      default:
        return ok(
          rows.where((row) {
            return ['student_id', 'timetable_slot_id', 'timestamp'].every((k) {
              final want = q[k];
              return want == null ||
                  !want.startsWith('eq.') ||
                  '${row[k]}' == want.substring(3);
            });
          }).toList(),
        );
    }
  }
}

AttendanceRecord record({int student = 7, double altitude = 1500.5}) =>
    AttendanceRecord(
      studentId: student,
      timetableSlotId: 3,
      type: 'CHECK-IN',
      timestamp: DateTime.now(),
      status: 'PRESENT',
      location: '0, 0',
      altitude: altitude,
      latitude: 0,
      longitude: 0,
    );

void main() {
  late FakeServer server;
  late CheckInRepository repo;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('cr_db');
    await databaseFactory.setDatabasesPath(dir.path);
  });

  setUp(() async {
    await (await DatabaseHelper.instance.database).delete('attendance_records');
    server = FakeServer();
    repo = CheckInRepository(client: server.client);
  });

  Future<List<Map<String, Object?>>> local() async =>
      (await DatabaseHelper.instance.database).query('attendance_records');

  test('S01 an online check-in keeps the server id', () async {
    server.nextId = 42;
    await repo.createAttendanceRecord(record());
    expect((await local()).single['id'], 42);
  });

  test('S02 an offline check-in uploads once when back online', () async {
    server.online = false;
    await repo.createAttendanceRecord(record());
    expect((await local()).single['id'] as int, isNegative);
    expect(await repo.syncPending(), 0);

    server.online = true;
    expect(await repo.syncPending(), 1);
    expect(await repo.syncPending(), 0);
    expect(server.rows, hasLength(1));
    expect((await local()).single['id'], server.rows.single['id']);
  });

  test(
    'S03 an offline check-out never touches another server record',
    () async {
      server.rows.add({...record(student: 99).toMap(), 'id': 1});
      server.nextId = 2;
      server.online = false;
      await repo.createAttendanceRecord(record());
      final id = (await local()).single['id'] as int;

      server.online = true;
      await repo.checkoutAttendanceRecord(id, DateTime.now().toIso8601String());
      expect(server.patched, isEmpty);
      expect(server.rows.single['checked_out_at'], isNull);

      await repo.syncPending();
      final mine = server.rows.singleWhere((r) => r['student_id'] == 7);
      expect(mine['checked_out_at'], isNotNull);
      expect(server.rows.first['checked_out_at'], isNull);
    },
  );

  test('S04 a lost reply does not create a duplicate', () async {
    server.loseReplies = true;
    await repo.createAttendanceRecord(record());
    expect(server.rows, hasLength(1));

    server.loseReplies = false;
    expect(await repo.syncPending(), 1);
    expect(server.rows, hasLength(1));
    expect(await local(), hasLength(1));
  });

  test('S05 several offline records do not overwrite each other', () async {
    server.online = false;
    for (var s = 1; s <= 5; s++) {
      await repo.createAttendanceRecord(record(student: s));
    }
    expect(await local(), hasLength(5));
    server.online = true;
    final counts = await Future.wait([repo.syncPending(), repo.syncPending()]);
    expect(counts, [5, 5], reason: 'concurrent calls share one run');
    expect(server.rows.map((r) => r['student_id']), [1, 2, 3, 4, 5]);
  });

  test('S06 whole numbers from the server are accepted', () {
    final r = AttendanceRecord.fromMap({
      ...record().toMap(),
      'id': 1,
      'altitude': 0,
      'latitude': 0,
      'longitude': 0,
    });
    expect(r.altitude, 0.0);
  });

  test('S07 automatic absences stay local when offline', () async {
    server.online = false;
    await repo.batchCreateAbsentRecords([1, 2], 3, DateTime.now());
    server.online = true;
    expect(await repo.syncPending(), 0);
    expect(server.rows, isEmpty);
    expect(await local(), hasLength(2));
  });

  group('attempt log', () {
    test('L01 round-trips awkward text and disarms formulas', () async {
      final dir = await Directory.systemTemp.createTemp('cr_log');
      final log = AttemptLog(directory: () async => dir);
      List<String> row(String note) => [
        't',
        'field-test',
        'Room "A", west',
        'inside',
        'inside',
        '-1.20',
        ...List.filled(AttemptLog.columns.length - 7, ''),
        note,
      ];
      await log.addRow(row('line one\nline two'));
      await log.addRow(row('=1+1'));
      final rows = await log.load();
      expect(rows, hasLength(2));
      expect(rows[0].venue, 'Room "A", west');
      expect(rows[0].height, '-1.20');
      expect(rows[0].note, 'line one line two');
      expect(rows[1].note, "'=1+1");
      expect(rows.every((r) => r.accepted), isTrue);
      await dir.delete(recursive: true);
    });
  });
}
