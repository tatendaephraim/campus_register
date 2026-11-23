import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../domain/attendance_policy.dart';

enum AttendanceType { signIn, signOut }

/// One immutable entry in the hash-chained log. Rejected attempts are logged as
/// well as accepted ones, because an evaluation needs both.
class AttendanceEvent {
  const AttendanceEvent({
    required this.deviceId,
    required this.seq,
    required this.studentId,
    required this.name,
    required this.type,
    required this.decision,
    required this.timestamp,
    required this.distanceM,
    required this.accuracyM,
    required this.locationMs,
    required this.biometricMs,
    required this.prevHash,
    required this.hash,
  });

  /// Predecessor hash of the first entry in a chain.
  static final String genesisHash = '0' * 64;

  static const List<String> fieldNames = [
    'deviceId',
    'seq',
    'studentId',
    'name',
    'type',
    'decision',
    'timestamp',
    'distanceM',
    'accuracyM',
    'locationMs',
    'biometricMs',
    'prevHash',
  ];

  final String deviceId;
  final int seq;
  final String studentId;
  final String name;
  final AttendanceType type;
  final Decision decision;

  /// ISO 8601, always UTC.
  final String timestamp;

  /// Distance from the campus reference point. Raw coordinates are never
  /// stored: the distance is enough to audit a decision.
  final String distanceM;
  final String accuracyM;
  final int locationMs;
  final int biometricMs;
  final String prevHash;
  final String hash;

  factory AttendanceEvent.create({
    required String deviceId,
    required int seq,
    required String studentId,
    required String name,
    required AttendanceType type,
    required Decision decision,
    required DateTime at,
    required String prevHash,
    double? distanceM,
    double? accuracyM,
    int locationMs = 0,
    int biometricMs = 0,
  }) {
    String metres(double? v) =>
        v == null || !v.isFinite ? '' : v.toStringAsFixed(1);
    final unsigned = AttendanceEvent(
      deviceId: deviceId,
      seq: seq,
      studentId: studentId,
      name: name,
      type: type,
      decision: decision,
      timestamp: at.toUtc().toIso8601String(),
      distanceM: metres(distanceM),
      accuracyM: metres(accuracyM),
      locationMs: locationMs,
      biometricMs: biometricMs,
      prevHash: prevHash,
      hash: '',
    );
    return AttendanceEvent.fromJson({
      ...unsigned.toJson(),
      'hash': unsigned.computeHash(),
    });
  }

  factory AttendanceEvent.fromJson(Map<String, dynamic> json) {
    String text(String key) => json[key] as String;
    return AttendanceEvent(
      deviceId: text('deviceId'),
      seq: int.parse(text('seq')),
      studentId: text('studentId'),
      name: text('name'),
      type: AttendanceType.values.byName(text('type')),
      decision: Decision.values.byName(text('decision')),
      timestamp: text('timestamp'),
      distanceM: text('distanceM'),
      accuracyM: text('accuracyM'),
      locationMs: int.parse(text('locationMs')),
      biometricMs: int.parse(text('biometricMs')),
      prevHash: text('prevHash'),
      hash: text('hash'),
    );
  }

  DateTime get time => DateTime.parse(timestamp);

  /// Field values in [fieldNames] order.
  List<String> get values => [
    deviceId,
    '$seq',
    studentId,
    name,
    type.name,
    decision.name,
    timestamp,
    distanceM,
    accuracyM,
    '$locationMs',
    '$biometricMs',
    prevHash,
  ];

  /// Every field travels as a string so that Dart and Apps Script hash exactly
  /// the same bytes, with no difference in number formatting.
  Map<String, String> toJson() => {
    for (var i = 0; i < fieldNames.length; i++) fieldNames[i]: values[i],
    'hash': hash,
  };

  /// SHA-256 over the JSON array of field values. Array encoding keeps field
  /// boundaries unambiguous, unlike joining with a separator.
  String computeHash() =>
      sha256.convert(utf8.encode(jsonEncode(values))).toString();
}

/// Returns the index of the first entry that breaks the chain, or null when the
/// chain is intact.
int? firstBrokenLink(List<AttendanceEvent> events) {
  var prev = AttendanceEvent.genesisHash;
  for (var i = 0; i < events.length; i++) {
    final e = events[i];
    if (e.seq != i || e.prevHash != prev || e.hash != e.computeHash()) return i;
    prev = e.hash;
  }
  return null;
}
