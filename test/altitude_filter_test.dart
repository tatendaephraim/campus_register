import 'dart:math' as math;

import 'package:campus_register/domain/altitude_filter.dart';
import 'package:flutter_test/flutter_test.dart';

final start = DateTime.utc(2026, 11, 23, 9);
DateTime at(num seconds) =>
    start.add(Duration(milliseconds: (seconds * 1000).round()));

/// Pressure at a height above the 850 hPa level.
double pressureAt(double height) {
  final base = pressureToAltitude(850);
  return 1013.25 * math.pow(1 - (base + height) / 44330, 5.255);
}

void main() {
  test('F01 has no estimate before the first GPS altitude', () {
    final f = AltitudeFilter()..addPressure(850, at(0));
    expect(f.estimate, isNull);
  });

  test('F02 starts at the first fix with its uncertainty', () {
    final f = AltitudeFilter()..addGnss(1500, 6, at(0));
    expect(f.estimate!.metres, 1500);
    expect(f.estimate!.sigma, 6);
    expect(f.estimate!.usedBarometer, isFalse);
  });

  test('F03 missing accuracy is treated as poor, not perfect', () {
    for (final s in [null, 0.0, -1.0, double.nan]) {
      final f = AltitudeFilter()..addGnss(1500, s, at(0));
      expect(f.estimate!.sigma, AltitudeFilter.unknownSigma);
    }
  });

  test('F04 tracks a climb of one floor by barometer alone', () {
    final f = AltitudeFilter()..addPressure(pressureAt(0), at(0));
    f.addGnss(1500, 4, at(0));
    for (var t = 1; t <= 30; t++) {
      f.addPressure(pressureAt(3.5 * t / 30), at(t));
    }
    expect(f.estimate!.metres, closeTo(1503.5, 0.1));
    expect(f.estimate!.usedBarometer, isTrue);
    expect(f.estimate!.sigma, lessThan(4.1));
  });

  test(
    'F05 barometer keeps a good outdoor altitude through a poor indoor fix',
    () {
      final withBarometer = AltitudeFilter()..addPressure(pressureAt(0), at(0));
      final gpsOnly = AltitudeFilter();
      for (final f in [withBarometer, gpsOnly]) {
        f.addGnss(1500, 3, at(0));
      }
      for (var t = 1; t <= 120; t++) {
        withBarometer.addPressure(pressureAt(0), at(t));
      }
      for (final f in [withBarometer, gpsOnly]) {
        f.addGnss(1512, 12, at(120));
      }
      expect((withBarometer.estimate!.metres - 1500).abs(), lessThan(1));
      expect(
        (gpsOnly.estimate!.metres - 1500).abs(),
        greaterThan((withBarometer.estimate!.metres - 1500).abs()),
      );
      expect(withBarometer.estimate!.sigma, lessThan(gpsOnly.estimate!.sigma));
    },
  );

  test('F06 absolute pressure is irrelevant, so weather offset cancels', () {
    double run(double offset) {
      final f = AltitudeFilter()..addPressure(850 + offset, at(0));
      f.addGnss(1500, 4, at(0));
      f.addPressure(849.6 + offset, at(1));
      return f.estimate!.metres;
    }

    expect(run(0), closeTo(run(8), 0.1));
  });

  test('F07 repeated fixes never claim more than twice the accuracy', () {
    final f = AltitudeFilter();
    for (var t = 0; t < 100; t++) {
      f.addGnss(1500, 10, at(t / 10));
    }
    expect(f.estimate!.sigma, greaterThanOrEqualTo(5));
  });

  test('F08 uncertainty grows without new evidence', () {
    final f = AltitudeFilter()..addPressure(850, at(0));
    f.addGnss(1500, 3, at(0));
    for (var t = 1; t <= 600; t++) {
      f.addPressure(850, at(t));
    }
    final later = f.estimate!.sigma;
    expect(later, greaterThan(3));
    expect(later, lessThan(4));
  });

  test('F09 a jump during a barometer gap is not integrated', () {
    final f = AltitudeFilter()..addPressure(850, at(0));
    f.addGnss(1500, 3, at(0));
    f.addPressure(840, at(60)); // App was in the background.
    expect(f.estimate!.metres, 1500);
    expect(f.estimate!.sigma, greaterThan(4));
  });

  test('F10 forgets an old session', () {
    final f = AltitudeFilter()
      ..addGnss(1500, 3, at(0))
      ..addGnss(1530, 8, at(700));
    expect(f.estimate!.metres, 1530);
    expect(f.estimate!.sigma, 8);
  });

  test('F11 a contradictory fix restarts the filter', () {
    final f = AltitudeFilter()
      ..addGnss(1500, 2, at(0))
      ..addGnss(1600, 2, at(1));
    expect(f.estimate!.metres, 1600);
  });

  test('F12 ignores faulty sensor values', () {
    final f = AltitudeFilter()..addPressure(850, at(0));
    f.addGnss(1500, 3, at(0));
    for (final p in [0.0, -5.0, 5000.0, double.nan, double.infinity]) {
      f.addPressure(p, at(1));
    }
    f.addGnss(double.nan, 3, at(1));
    expect(f.estimate!.metres, 1500);
  });

  test('F13 ignores pressure that arrives out of order', () {
    final f = AltitudeFilter()..addPressure(850, at(10));
    f.addGnss(1500, 3, at(10));
    f.addPressure(840, at(5));
    expect(f.estimate!.metres, 1500);
  });
}
