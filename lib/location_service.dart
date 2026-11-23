import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'domain/volumetric_check.dart' as volumetric;
import 'venue.dart';

/// A service to handle location permissions and fetching the device's position.
class LocationService {
  Future<void> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw 'Location services are disabled. Please enable them in your device settings.';
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Location permissions are denied.';
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw 'Location permissions are permanently denied. Please enable them in settings.';
    }
  }

  /// Checks for location permissions and fetches the current position.
  Future<Position> getCurrentPositionWithPermissions() async {
    await _ensurePermission();
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 10),
        ),
      );
    } on TimeoutException {
      throw 'Could not get location in time. Please try again.';
    }
  }

  /// Collects a few consecutive fixes, which steadies the altitude. Returns
  /// early with whatever has arrived, and throws only if there is nothing.
  Future<List<Position>> getFixes({
    int count = 3,
    Duration timeLimit = const Duration(seconds: 12),
  }) async {
    await _ensurePermission();
    final fixes = <Position>[];
    try {
      await for (final p in Geolocator.getPositionStream(
        locationSettings: const LocationSettings(),
      ).timeout(timeLimit)) {
        // The stream may open with an old cached position.
        if (DateTime.now().difference(p.timestamp).abs() >
            const Duration(seconds: 30)) {
          continue;
        }
        fixes.add(p);
        if (fixes.length >= count) break;
      }
    } on TimeoutException {
      // Use what has arrived.
    } on LocationServiceDisabledException {
      throw 'Location services are disabled. Please enable them in your device settings.';
    }
    if (fixes.isEmpty) {
      throw 'Could not get location in time. Please try again.';
    }
    return fixes;
  }

  /// Check if a point is inside a polygon using ray casting, allowing a 5-meter
  /// tolerance (extruding out) to compensate for GPS lateral errors.
  bool isPointInPolygon(
    double latitude,
    double longitude,
    List<LatLng> polygon,
  ) => volumetric.isPointInPolygon(latitude, longitude, polygon);
}
