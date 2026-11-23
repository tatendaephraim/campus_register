import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

class AltitudeService {
  // Make this a singleton so that the barometer stream subscription is shared.
  AltitudeService._privateConstructor() {
    _initBarometer();
  }
  static final AltitudeService instance = AltitudeService._privateConstructor();

  static const double seaLevelPressure = 1013.25;
  double? _latestPressure;
  StreamSubscription<BarometerEvent>? _barometerSubscription;

  void _initBarometer() {
    try {
      _barometerSubscription = barometerEventStream().listen((event) {
        _latestPressure = event.pressure;
      }, onError: (e) {
        print("Barometer not supported or error: $e");
      });
    } catch (e) {
      print("Failed to initialize barometer stream: $e");
    }
  }

  void dispose() {
    _barometerSubscription?.cancel();
    _barometerSubscription = null;
  }

  /// Converts Hectopascals (hPa) to Altitude in Meters
  /// Uses the International Barometric Formula
  double pressureToAltitude(double pressureHpa) {
    if (pressureHpa <= 0) return 0.0;
    return 44330.0 * (1.0 - pow(pressureHpa / seaLevelPressure, 1.0 / 5.255));
  }

  /// Gets the combined altitude using both Barometer (if available) and GPS.
  double getCombinedAltitude(double gpsAltitude) {
    // Bypassing barometric pressure averaging to avoid uncalibrated drift anomalies.
    print("Altitude Debug: GPS Only (barometer bypassed)=$gpsAltitude m");
    return gpsAltitude;
  }

  /// Calculates the estimated floor number
  int calculateFloor(double currentAlt, double groundAlt) {
    double heightAboveGround = currentAlt - groundAlt;
    int floor = (heightAboveGround / 3.5).floor();
    return floor < 0 ? 0 : floor;
  }
}
