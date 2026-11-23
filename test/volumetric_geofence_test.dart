import 'package:campus_register/domain/altitude_filter.dart';
import 'package:campus_register/domain/volumetric_check.dart';
import 'package:campus_register/services/altitude_service.dart';
import 'package:campus_register/venue.dart';
import 'package:flutter_test/flutter_test.dart';

/// Metres per degree of latitude, for placing test points.
const mPerDeg = 111195.0;
const floorM = 3.5;
final now = DateTime.utc(2026, 11, 23, 9);

/// A 20 m by 20 m room centred on (0, 0), floor at 1500 m.
Venue room({
  double tolerance = 12,
  bool polygon = true,
  double altitude = 1500,
}) {
  const h = 10 / mPerDeg;
  return Venue(
    id: 1,
    name: 'Room',
    latitude: 0,
    longitude: 0,
    altitude: altitude,
    radius: 50,
    verticalTolerance: tolerance,
    polygonCorners: polygon
        ? const [LatLng(-h, -h), LatLng(-h, h), LatLng(h, h), LatLng(h, -h)]
        : null,
  );
}

VolumetricResult evaluate({
  double north = 0,
  double east = 0,
  double? height = 0,
  double sigma = 3,
  double accuracy = 8,
  Duration age = Duration.zero,
  bool mocked = false,
  bool allowCircle = false,
  Venue? venue,
  bool noVenue = false,
}) {
  final v = venue ?? room();
  return const VolumetricCheck().evaluate(
    venue: noVenue ? null : v,
    sample: GeoSample(
      latitude: north / mPerDeg,
      longitude: east / mPerDeg,
      accuracyM: accuracy,
      timestamp: now.subtract(age),
      isMocked: mocked,
    ),
    altitude: height == null
        ? null
        : AltitudeEstimate(v.altitude + height, sigma),
    now: now,
    allowCircle: allowCircle,
  );
}

void main() {
  const d = VolumetricDecision.values;
  assert(d.isNotEmpty);

  group('horizontal test cases', () {
    void tc(String id, double north, double east, VolumetricDecision want) =>
        test('$id at ($north N, $east E) is ${want.name}', () {
          expect(evaluate(north: north, east: east).decision, want);
        });

    tc('H01 centre', 0, 0, VolumetricDecision.inside);
    tc('H02 by the north wall', 9.9, 0, VolumetricDecision.inside);
    tc('H03 in a corner', 9.9, 9.9, VolumetricDecision.inside);
    tc('H04 4 m past the wall, in tolerance', 14, 0, VolumetricDecision.inside);
    tc('H05 6 m past the wall', 16, 0, VolumetricDecision.outsideBoundary);
    tc(
      'H06 past a corner, diagonal',
      14,
      14,
      VolumetricDecision.outsideBoundary,
    );
    tc('H07 next room', 25, 0, VolumetricDecision.outsideBoundary);
    tc('H08 across campus', 500, 300, VolumetricDecision.outsideBoundary);

    test('H09 a concave room does not include its notch', () {
      LatLng p(double n, double e) => LatLng(n / mPerDeg, e / mPerDeg);
      final lShape = [
        p(0, 0),
        p(0, 60),
        p(20, 60),
        p(20, 20),
        p(60, 20),
        p(60, 0),
      ];
      bool inside(double n, double e) =>
          isPointInPolygon(n / mPerDeg, e / mPerDeg, lShape);
      expect(inside(10, 50), isTrue);
      expect(inside(50, 10), isTrue);
      expect(inside(50, 50), isFalse);
    });

    test('H10 corner order does not matter', () {
      final corners = room().polygonCorners!;
      for (final c in [corners, corners.reversed.toList()]) {
        expect(isPointInPolygon(0, 0, c), isTrue);
        expect(isPointInPolygon(20 / mPerDeg, 0, c), isFalse);
      }
    });

    test('H11 tolerance is metres east-west too, away from the equator', () {
      const lat = 60.0; // A degree of longitude is half as long here.
      const h = 10 / mPerDeg;
      const corners = [
        LatLng(lat - h, -2 * h),
        LatLng(lat - h, 2 * h),
        LatLng(lat + h, 2 * h),
        LatLng(lat + h, -2 * h),
      ];
      double lon(double metres) => metres / (mPerDeg * 0.5);
      expect(isPointInPolygon(lat, lon(14), corners), isTrue);
      expect(isPointInPolygon(lat, lon(16), corners), isFalse);
    });

    test('H12 fewer than three corners is never inside', () {
      expect(
        isPointInPolygon(0, 0, const [LatLng(0, 0), LatLng(1, 1)]),
        isFalse,
      );
    });
  });

  group('vertical test cases, default band -8 to +12 m', () {
    void tc(
      String id,
      double height,
      VolumetricDecision want, {
      double s = 3,
    }) => test('$id: $height m, sigma $s is ${want.name}', () {
      expect(evaluate(height: height, sigma: s).decision, want);
    });

    tc('V01 on the floor', 0, VolumetricDecision.inside);
    tc('V02 phone held up', 1.5, VolumetricDecision.inside);
    tc('V03 just under the ceiling of the band', 11, VolumetricDecision.inside);
    tc('V04 just above the band', 13, VolumetricDecision.altitudeUncertain);
    tc('V05 five floors up', 5 * floorM, VolumetricDecision.tooHigh);
    tc('V06 ten floors up', 10 * floorM, VolumetricDecision.tooHigh);
    tc('V07 just below the band', -9, VolumetricDecision.altitudeUncertain);
    tc('V08 four floors down', -4 * floorM, VolumetricDecision.tooLow);
    tc(
      'V09 very poor altitude is never accepted',
      0,
      VolumetricDecision.altitudeUncertain,
      s: 30,
    );
    tc('V10 poor but usable altitude', 0, VolumetricDecision.inside, s: 12);

    // Documents the cost of the wide default: the next floor is not excluded.
    tc(
      'V11 KNOWN LIMIT one floor up is accepted',
      floorM,
      VolumetricDecision.inside,
    );
    tc(
      'V12 KNOWN LIMIT two floors up is accepted',
      2 * floorM,
      VolumetricDecision.inside,
    );
  });

  group('vertical test cases, tight band -2 to +2 m', () {
    void tc(String id, double height, double s, VolumetricDecision want) =>
        test('$id: $height m, sigma $s is ${want.name}', () {
          expect(
            evaluate(
              height: height,
              sigma: s,
              venue: room(tolerance: 2),
            ).decision,
            want,
          );
        });

    tc(
      'T01 on the floor, barometer-grade altitude',
      0,
      0.7,
      VolumetricDecision.inside,
    );
    tc('T02 one floor up is excluded', floorM, 0.7, VolumetricDecision.tooHigh);
    tc(
      'T03 one floor down is excluded',
      -floorM,
      0.7,
      VolumetricDecision.tooLow,
    );
    tc(
      'T04 good GPS alone cannot separate floors',
      0,
      4,
      VolumetricDecision.altitudeUncertain,
    );
    tc(
      'T05 poor GPS is undecided one floor up',
      floorM,
      10,
      VolumetricDecision.altitudeUncertain,
    );
  });

  group('evidence quality test cases', () {
    test('Q01 mocked location', () {
      expect(
        evaluate(mocked: true).decision,
        VolumetricDecision.mockedLocation,
      );
    });
    test('Q02 stale fix', () {
      expect(
        evaluate(age: const Duration(seconds: 31)).decision,
        VolumetricDecision.staleFix,
      );
    });
    test('Q03 fix from the future, so the clock was set back', () {
      expect(
        evaluate(age: const Duration(minutes: -5)).decision,
        VolumetricDecision.staleFix,
      );
    });
    test('Q04 coarse horizontal fix', () {
      expect(evaluate(accuracy: 60).decision, VolumetricDecision.poorAccuracy);
    });
    test('Q05 unknown accuracy is not perfect accuracy', () {
      for (final a in [0.0, -1.0, double.nan, double.infinity]) {
        expect(evaluate(accuracy: a).decision, VolumetricDecision.poorAccuracy);
      }
    });
    test('Q06 no altitude fails closed', () {
      expect(evaluate(height: null).decision, VolumetricDecision.noAltitude);
    });
    test('Q07 missing venue fails closed', () {
      expect(evaluate(noVenue: true).decision, VolumetricDecision.invalidVenue);
    });
    test('Q08 classroom without a polygon fails closed', () {
      expect(
        evaluate(venue: room(polygon: false)).decision,
        VolumetricDecision.invalidVenue,
      );
    });
    test('Q09 circular office enforces both radius and height', () {
      VolumetricDecision at(double north, double height) => evaluate(
        venue: room(polygon: false),
        allowCircle: true,
        north: north,
        height: height,
      ).decision;
      expect(at(40, 0), VolumetricDecision.inside);
      expect(at(60, 0), VolumetricDecision.outsideBoundary);
      expect(at(0, 60), VolumetricDecision.tooHigh);
    });
    test('Q10 NaN coordinates are never inside', () {
      expect(
        evaluate(north: double.nan).decision,
        VolumetricDecision.outsideBoundary,
      );
    });
    test(
      'Q11 right height, wrong place, and the reverse, are both refused',
      () {
        expect(evaluate(north: 100).decision.isInside, isFalse);
        expect(evaluate(height: 60).decision.isInside, isFalse);
      },
    );
  });

  group('height band', () {
    test('B01 stored tolerance sets the band', () {
      final b = HeightBand.forVenue(room(tolerance: 3));
      expect((b.below, b.above), (3, 3));
    });
    test('B02 default keeps -8 to +12', () {
      final b = HeightBand.forVenue(room(tolerance: 0));
      expect((b.below, b.above), (8, 12));
    });
    test('B03 probabilities are correct', () {
      const b = HeightBand(1, 1);
      expect(b.probability(0, 1), closeTo(0.6827, 1e-4));
      expect(b.probability(0, 0), 1);
      expect(b.probability(5, 0), 0);
      expect(b.probability(1, 0.001), closeTo(0.5, 1e-3));
    });
  });

  group('barometric formula', () {
    final service = AltitudeService.instance;
    test('P01 sea level and 900 hPa', () {
      expect(service.pressureToAltitude(1013.25), closeTo(0, 0.1));
      expect(service.pressureToAltitude(900), closeTo(989, 5));
    });
    test('P02 invalid pressure', () {
      expect(service.pressureToAltitude(0), 0);
      expect(service.pressureToAltitude(-50), 0);
      expect(pressureToAltitude(double.nan), 0);
    });
    test('P03 floor offset', () {
      expect(service.floorOffset(1500, 1500), 0);
      expect(service.floorOffset(1503.5, 1500), 1);
      expect(service.floorOffset(1493, 1500), -2);
    });
  });
}
