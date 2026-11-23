import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/altitude_filter.dart';
import '../domain/volumetric_check.dart';
import '../location_service.dart';
import '../venue.dart';
import 'altitude_service.dart';
import 'attempt_log.dart';

/// A 3D verdict together with the evidence behind it.
class VolumetricReading {
  const VolumetricReading({
    required this.result,
    required this.position,
    required this.altitude,
    required this.pressureHpa,
  });

  final VolumetricResult result;
  final Position position;
  final AltitudeEstimate? altitude;
  final double? pressureHpa;

  /// Fused altitude, falling back to the raw GPS value for the stored record.
  double get altitudeM => altitude?.metres ?? position.altitude;
}

/// Collects sensor evidence and applies [VolumetricCheck]. Every place that
/// enforces presence goes through here, so the rules cannot drift apart.
class VolumetricVerifier {
  VolumetricVerifier({
    LocationService? locationService,
    this.check = const VolumetricCheck(),
  }) : _location = locationService ?? LocationService();

  final LocationService _location;
  final VolumetricCheck check;

  /// [source] names the caller in the attempt log, for example `check-in`.
  Future<VolumetricReading> verify(
    Venue? venue, {
    required String source,
    bool allowCircle = false,
    String expected = '',
    String note = '',
  }) async {
    final altitudeService = AltitudeService.instance..start();
    final fixes = await _location.getFixes();
    for (final fix in fixes) {
      if (_hasAltitude(fix) && !fix.isMocked) {
        altitudeService.addGnss(fix.altitude, fix.altitudeAccuracy);
      }
    }
    // Any mocked fix taints the sample. Otherwise the most precise one wins.
    final best =
        fixes.where((f) => f.isMocked).firstOrNull ??
        fixes.reduce((a, b) => b.accuracy < a.accuracy ? b : a);

    // A filter that has no altitude from this attempt must not answer from
    // memory: the phone may have moved since.
    final altitude = fixes.any(_hasAltitude) ? altitudeService.estimate : null;
    final reading = VolumetricReading(
      result: check.evaluate(
        venue: venue,
        sample: GeoSample(
          latitude: best.latitude,
          longitude: best.longitude,
          accuracyM: best.accuracy,
          timestamp: best.timestamp,
          isMocked: best.isMocked,
        ),
        altitude: altitude,
        now: DateTime.now(),
        allowCircle: allowCircle,
      ),
      position: best,
      altitude: altitude,
      pressureHpa: altitudeService.latestPressure,
    );
    try {
      await AttemptLog.instance.add(
        reading: reading,
        venue: venue,
        source: source,
        expected: expected,
        note: note,
      );
    } catch (e) {
      debugPrint('Attempt log could not be written: $e');
    }
    return reading;
  }

  /// Like [verify], but throws the reason when the phone is not inside.
  Future<VolumetricReading> require(
    Venue? venue, {
    required String source,
    bool allowCircle = false,
  }) async {
    final reading = await verify(
      venue,
      source: source,
      allowCircle: allowCircle,
    );
    if (!reading.result.decision.isInside) {
      throw reading.result.decision.message;
    }
    return reading;
  }

  /// Android reports exactly 0 for both values when a fix has no altitude.
  static bool _hasAltitude(Position p) =>
      p.altitude.isFinite && (p.altitude != 0 || p.altitudeAccuracy > 0);
}
