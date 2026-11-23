import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../domain/altitude_filter.dart' as filter;

/// Feeds the barometer and GPS altitude into one shared altitude filter.
class AltitudeService {
  AltitudeService._();
  static final AltitudeService instance = AltitudeService._();

  final filter.AltitudeFilter _filter = filter.AltitudeFilter();
  StreamSubscription<BarometerEvent>? _subscription;
  double? _latestPressure;

  double? get latestPressure => _latestPressure;
  filter.AltitudeEstimate? get estimate => _filter.estimate;

  /// Starts listening. Safe to call repeatedly, and on phones that have no
  /// barometer, where the filter falls back to GPS alone.
  void start() {
    if (_subscription != null) return;
    try {
      _subscription =
          barometerEventStream(
            samplingPeriod: SensorInterval.uiInterval,
          ).listen(
            (event) {
              _latestPressure = event.pressure;
              _filter.addPressure(event.pressure, DateTime.now());
            },
            onError: (Object e) => debugPrint('Barometer unavailable: $e'),
            cancelOnError: true,
          );
    } catch (e) {
      debugPrint('Barometer unavailable: $e');
    }
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// [sigma] is the vertical accuracy the phone reported, if any.
  void addGnss(double altitude, double? sigma) =>
      _filter.addGnss(altitude, sigma, DateTime.now());

  void reset() => _filter.reset();

  /// Converts pressure (hPa) to altitude above the standard sea level.
  double pressureToAltitude(double pressureHpa) =>
      filter.pressureToAltitude(pressureHpa);

  /// Storeys above a ground altitude, never below the ground floor.
  int calculateFloor(double currentAlt, double groundAlt) {
    final floor = ((currentAlt - groundAlt) / 3.5).floor();
    return floor < 0 ? 0 : floor;
  }

  /// Floors above (or below, if negative) the venue's own floor.
  int floorOffset(double altitude, double venueAltitude) =>
      ((altitude - venueAltitude) / 3.5).round();
}
