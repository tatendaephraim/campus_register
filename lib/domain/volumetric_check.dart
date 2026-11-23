import 'dart:math' as math;

import '../venue.dart';
import 'altitude_filter.dart';

/// One position fix, independent of any plugin.
class GeoSample {
  const GeoSample({
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.timestamp,
    this.isMocked = false,
  });

  final double latitude;
  final double longitude;
  final double accuracyM;
  final DateTime timestamp;
  final bool isMocked;
}

/// Outcome of the 3D check. Names are written to the attempt log.
enum VolumetricDecision {
  inside('You are inside the classroom volume.'),
  invalidVenue(
    'The class geofence is not set up. It needs at least 3 corners.',
  ),
  mockedLocation('A fake-location app is active. Turn it off and try again.'),
  staleFix('Your position is out of date. Please try again.'),
  poorAccuracy('GPS is too weak here. Move near a window and try again.'),
  outsideBoundary(
    'You are not inside the classroom. Sign-in is restricted to the 3D class '
    'boundary.',
  ),
  noAltitude(
    'Your phone has no altitude reading yet. Move near a window and try again.',
  ),
  altitudeUncertain(
    'Your floor could not be confirmed. Hold the phone still near a window and '
    'try again.',
  ),
  tooLow('You appear to be below the classroom floor.'),
  tooHigh('You appear to be on a floor above the classroom.');

  const VolumetricDecision(this.message);
  final String message;

  bool get isInside => this == VolumetricDecision.inside;
}

class VolumetricResult {
  const VolumetricResult(
    this.decision, {
    this.heightM,
    this.sigmaM,
    this.probability,
  });

  final VolumetricDecision decision;

  /// Estimated height above the venue floor.
  final double? heightM;
  final double? sigmaM;

  /// Probability that the phone is inside the height band.
  final double? probability;
}

/// Height band around a venue's captured floor altitude.
class HeightBand {
  const HeightBand(this.below, this.above);

  /// The tolerance stored with the venue sets how far above the floor counts as
  /// inside. The same distance applies below it, up to 8 m.
  factory HeightBand.forVenue(Venue venue) {
    final above = venue.verticalTolerance > 0 ? venue.verticalTolerance : 12.0;
    return HeightBand(math.min(8.0, above), above);
  }

  final double below;
  final double above;

  /// Probability that a normally distributed height lies inside the band.
  double probability(double height, double sigma) {
    if (sigma <= 0) return height >= -below && height <= above ? 1 : 0;
    return _normalCdf((above - height) / sigma) -
        _normalCdf((-below - height) / sigma);
  }
}

/// Decides whether a phone is inside a venue's 3D volume.
class VolumetricCheck {
  const VolumetricCheck({
    this.edgeToleranceM = 5,
    this.maxAccuracyM = 35,
    this.maxFixAge = const Duration(seconds: 30),
    this.acceptProbability = 0.5,
    this.rejectProbability = 0.1,
  });

  final double edgeToleranceM;
  final double maxAccuracyM;
  final Duration maxFixAge;
  final double acceptProbability;
  final double rejectProbability;

  /// Staff offices may be circles; classrooms must have a polygon.
  VolumetricResult evaluate({
    required Venue? venue,
    required GeoSample sample,
    required AltitudeEstimate? altitude,
    required DateTime now,
    bool allowCircle = false,
  }) {
    if (venue == null || !(venue.hasPolygon || allowCircle)) {
      return const VolumetricResult(VolumetricDecision.invalidVenue);
    }
    if (sample.isMocked) {
      return const VolumetricResult(VolumetricDecision.mockedLocation);
    }
    if (now.difference(sample.timestamp).abs() > maxFixAge) {
      return const VolumetricResult(VolumetricDecision.staleFix);
    }
    final inside = venue.hasPolygon
        ? isPointInPolygon(
            sample.latitude,
            sample.longitude,
            venue.polygonCorners!,
            toleranceM: edgeToleranceM,
          )
        : distanceMetres(
                sample.latitude,
                sample.longitude,
                venue.latitude,
                venue.longitude,
              ) <=
              venue.radius;
    final accuracy = sample.accuracyM;
    final accurate =
        accuracy.isFinite && accuracy > 0 && accuracy <= maxAccuracyM;
    if (!accurate) {
      return const VolumetricResult(VolumetricDecision.poorAccuracy);
    }
    if (!inside) {
      return const VolumetricResult(VolumetricDecision.outsideBoundary);
    }
    if (altitude == null) {
      return const VolumetricResult(VolumetricDecision.noAltitude);
    }

    final band = HeightBand.forVenue(venue);
    final height = altitude.metres - venue.altitude;
    final p = band.probability(height, altitude.sigma);
    final VolumetricDecision decision;
    if (p >= acceptProbability) {
      decision = VolumetricDecision.inside;
    } else if (p <= rejectProbability && height > band.above) {
      decision = VolumetricDecision.tooHigh;
    } else if (p <= rejectProbability && height < -band.below) {
      decision = VolumetricDecision.tooLow;
    } else {
      decision = VolumetricDecision.altitudeUncertain;
    }
    return VolumetricResult(
      decision,
      heightM: height,
      sigmaM: altitude.sigma,
      probability: p,
    );
  }
}

/// Great-circle distance in metres (haversine).
double distanceMetres(double lat1, double lon1, double lat2, double lon2) {
  const toRad = math.pi / 180;
  final sinLat = math.sin((lat2 - lat1) * toRad / 2);
  final sinLon = math.sin((lon2 - lon1) * toRad / 2);
  final a =
      sinLat * sinLat +
      math.cos(lat1 * toRad) * math.cos(lat2 * toRad) * sinLon * sinLon;
  return 2 * 6371008.8 * math.asin(math.sqrt(math.min(1.0, a)));
}

/// Ray casting, extended outwards by [toleranceM] to absorb lateral GPS error.
bool isPointInPolygon(
  double latitude,
  double longitude,
  List<LatLng> polygon, {
  double toleranceM = 5,
}) {
  if (polygon.length < 3 || !latitude.isFinite || !longitude.isFinite) {
    return false;
  }
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final a = polygon[i];
    final b = polygon[j];
    if ((a.longitude > longitude) != (b.longitude > longitude) &&
        latitude <
            (b.latitude - a.latitude) *
                    (longitude - a.longitude) /
                    (b.longitude - a.longitude) +
                a.latitude) {
      inside = !inside;
    }
  }
  if (inside) return true;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    if (_distanceToSegment(latitude, longitude, polygon[i], polygon[j]) <=
        toleranceM) {
      return true;
    }
  }
  return false;
}

double _distanceToSegment(double lat, double lon, LatLng a, LatLng b) {
  // Scale longitude so that both axes measure the same length locally.
  final cosLat = math.cos((a.latitude + b.latitude) / 2 * math.pi / 180);
  final vx = b.latitude - a.latitude;
  final vy = (b.longitude - a.longitude) * cosLat;
  final wx = lat - a.latitude;
  final wy = (lon - a.longitude) * cosLat;
  final lengthSquared = vx * vx + vy * vy;
  final t = lengthSquared == 0
      ? 0.0
      : ((wx * vx + wy * vy) / lengthSquared).clamp(0.0, 1.0);
  return distanceMetres(
    lat,
    lon,
    a.latitude + t * (b.latitude - a.latitude),
    a.longitude + t * (b.longitude - a.longitude),
  );
}

/// Standard normal CDF (Abramowitz and Stegun 7.1.26; error below 1.5e-7).
double _normalCdf(double x) {
  final z = x.abs() / math.sqrt2;
  final t = 1 / (1 + 0.3275911 * z);
  final poly =
      t *
      (0.254829592 +
          t *
              (-0.284496736 +
                  t * (1.421413741 + t * (-1.453152027 + t * 1.061405429))));
  final erf = 1 - poly * math.exp(-z * z);
  return x >= 0 ? (1 + erf) / 2 : (1 - erf) / 2;
}
