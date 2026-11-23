import 'dart:convert';
import 'dart:io';

import '../models/attendance_event.dart';
import '../models/student_profile.dart';

/// Thrown when the log on disk cannot be parsed. The caller must not append to
/// it, because that would bury the damage under new entries.
class CorruptLogException implements Exception {
  const CorruptLogException(this.line);
  final int line;

  @override
  String toString() => 'The attendance log is unreadable at line $line.';
}

/// Append-only storage in the app's private directory.
///
/// Events are one JSON object per line and are never rewritten. Because they
/// are uploaded strictly in order, sync state is a single counter in its own
/// file rather than a mutable flag on each entry.
class AttendanceStore {
  AttendanceStore(this._directory);

  final Directory _directory;

  File get _log => File('${_directory.path}/attendance.jsonl');
  File get _cursor => File('${_directory.path}/sync_cursor');
  File get _profile => File('${_directory.path}/profile.json');

  Future<StudentProfile?> loadProfile() async {
    if (!await _profile.exists()) return null;
    return StudentProfile.fromJson(
      jsonDecode(await _profile.readAsString()) as Map<String, dynamic>,
    );
  }

  Future<void> saveProfile(StudentProfile profile) =>
      _replace(_profile, jsonEncode(profile.toJson()));

  Future<List<AttendanceEvent>> loadEvents() async {
    if (!await _log.exists()) return [];
    var bytes = await _log.readAsBytes();
    // Every append ends in a newline, so a tail without one is a write that was
    // cut short by a crash. It was never acknowledged; drop it.
    final end = bytes.lastIndexOf(0x0A) + 1;
    if (end != bytes.length) {
      final raf = await _log.open(mode: FileMode.append);
      try {
        await raf.truncate(end);
      } finally {
        await raf.close();
      }
      bytes = bytes.sublist(0, end);
    }
    final events = <AttendanceEvent>[];
    var lineNumber = 0;
    for (final line in const LineSplitter().convert(
      utf8.decode(bytes, allowMalformed: true),
    )) {
      lineNumber++;
      try {
        events.add(
          AttendanceEvent.fromJson(jsonDecode(line) as Map<String, dynamic>),
        );
      } catch (_) {
        throw CorruptLogException(lineNumber);
      }
    }
    return events;
  }

  Future<void> append(AttendanceEvent event) => _log.writeAsString(
    '${jsonEncode(event.toJson())}\n',
    mode: FileMode.append,
    flush: true,
  );

  /// Number of leading events the server has acknowledged.
  Future<int> loadSyncedCount() async {
    if (!await _cursor.exists()) return 0;
    // An unreadable cursor is safe to reset: the server ignores duplicates.
    return int.tryParse((await _cursor.readAsString()).trim()) ?? 0;
  }

  Future<void> saveSyncedCount(int count) => _replace(_cursor, '$count');

  Future<void> _replace(File target, String contents) async {
    final temp = File('${target.path}.tmp');
    await temp.writeAsString(contents, flush: true);
    await temp.rename(target.path);
  }
}
