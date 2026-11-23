import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'venue.dart';

/// A service to handle location permissions and fetching the device's position.
class LocationService {
  /// Checks for location permissions and fetches the current position.
  Future<Position> getCurrentPositionWithPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Location services are disabled. Please enable them in your device settings.';
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Location permissions are denied.';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw 'Location permissions are permanently denied. Please enable them in settings.';
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 10),
      );
    } on TimeoutException {
      throw 'Could not get location in time. Please try again.';
    }
  }

  /// Check if a point is inside a polygon using ray casting, allowing a 5-meter
  /// tolerance (extruding out) to compensate for GPS lateral errors.
  bool isPointInPolygon(double latitude, double longitude, List<LatLng> polygon) {
    if (polygon.length < 3) return false;

    // 1. Check if point is naturally inside using Ray Casting
    bool inside = false;
    int j = polygon.length - 1;

    for (int i = 0; i < polygon.length; i++) {
      double xi = polygon[i].latitude;
      double yi = polygon[i].longitude;
      double xj = polygon[j].latitude;
      double yj = polygon[j].longitude;

      bool intersect = ((yi > longitude) != (yj > longitude)) &&
          (latitude < (xj - xi) * (longitude - yi) / (yj - yi) + xi);

      if (intersect) inside = !inside;
      j = i;
    }

    if (inside) return true;

    // 2. Check if point is within 5 meters of any polygon segment (lateral tolerance)
    const double toleranceMeters = 5.0;
    j = polygon.length - 1;
    for (int i = 0; i < polygon.length; i++) {
      final double dist = _distanceToSegment(
        latitude,
        longitude,
        polygon[i].latitude,
        polygon[i].longitude,
        polygon[j].latitude,
        polygon[j].longitude,
      );

      if (dist <= toleranceMeters) {
        return true;
      }
      j = i;
    }

    return false;
  }

  /// Calculate the minimum distance in meters from a point P to a line segment AB.
  double _distanceToSegment(
      double latP, double lonP, double latA, double lonA, double latB, double lonB) {
    final double latMidRad = ((latA + latB) / 2) * math.pi / 180.0;
    final double cosLat = math.cos(latMidRad);

    // Vector v = B - A
    final double vx = latB - latA;
    final double vy = (lonB - lonA) * cosLat;

    // Vector w = P - A
    final double wx = latP - latA;
    final double wy = (lonP - lonA) * cosLat;

    final double v2 = vx * vx + vy * vy;
    if (v2 == 0) {
      // A and B are the same point
      return Geolocator.distanceBetween(latP, lonP, latA, lonA);
    }

    // Projection factor clamped to segment [0, 1]
    double t = (wx * vx + wy * vy) / v2;
    t = t.clamp(0.0, 1.0);

    // Closest point C on segment AB
    final double latC = latA + t * (latB - latA);
    final double lonC = lonA + t * (lonB - lonA);

    return Geolocator.distanceBetween(latP, lonP, latC, lonC);
  }
}
