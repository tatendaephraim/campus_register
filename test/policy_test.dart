import 'package:campus_register/domain/attendance_policy.dart';
import 'package:campus_register/domain/geofence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 11, 23, 9);
  const policy = AttendancePolicy(latitude: 0, longitude: 0, radiusM: 100);

  // At the equator one degree of latitude is about 111 195 m.
  PositionSample at(
    double metres, {
    double accuracy = 5,
    Duration age = Duration.zero,
    bool mocked = false,
  }) => PositionSample(
    latitude: metres / 111195,
    longitude: 0,
    accuracyM: accuracy,
    timestamp: now.subtract(age),
    isMocked: mocked,
  );

  Decision decide(PositionSample? p, {DateTime? last}) =>
      policy.evaluate(position: p, now: now, lastEventAt: last).decision;

  test('haversine matches known distances', () {
    expect(haversineMetres(0, 0, 0, 1), closeTo(111195, 1));
    expect(haversineMetres(-1.9, 30.1, -1.9, 30.1), 0);
    // Antipodes must not produce NaN through rounding.
    expect(haversineMetres(0, 0, 0, 180), closeTo(20015115, 1000));
  });

  test('fence boundaries are exact', () {
    FenceResult f(double d) =>
        classifyFence(distanceM: d, accuracyM: 10, radiusM: 100);
    expect(f(90), FenceResult.inside);
    expect(f(90.1), FenceResult.uncertain);
    expect(f(110), FenceResult.uncertain);
    expect(f(110.1), FenceResult.outside);
  });

  test('accepts a good fix inside', () {
    expect(decide(at(20)), Decision.accepted);
  });

  test('declines to decide near the edge', () {
    expect(decide(at(98)), Decision.boundaryUncertain);
  });

  test('rejects a fix outside', () {
    expect(decide(at(500)), Decision.outsideCampus);
  });

  test('reports far away as outside even with a coarse fix', () {
    expect(decide(at(5000, accuracy: 900)), Decision.outsideCampus);
  });

  test('rejects a coarse fix at the centre', () {
    expect(decide(at(0, accuracy: 80)), Decision.poorAccuracy);
  });

  test('treats unknown accuracy as poor, not perfect', () {
    expect(decide(at(0, accuracy: 0)), Decision.poorAccuracy);
    expect(decide(at(0, accuracy: -1)), Decision.poorAccuracy);
    expect(decide(at(0, accuracy: double.nan)), Decision.poorAccuracy);
  });

  test('rejects mock providers', () {
    expect(decide(at(0, mocked: true)), Decision.mockedPosition);
  });

  test('rejects stale fixes', () {
    expect(decide(at(0, age: const Duration(seconds: 31))), Decision.staleFix);
  });

  test('rejects a missing or unusable position', () {
    expect(decide(null), Decision.noPosition);
    expect(decide(at(double.nan)), Decision.noPosition);
  });

  test('detects a clock set back, by the log and by the fix', () {
    expect(
      decide(at(0), last: now.add(const Duration(minutes: 1))),
      Decision.clockInconsistent,
    );
    expect(
      decide(at(0, age: const Duration(minutes: -5))),
      Decision.clockInconsistent,
    );
  });
}
