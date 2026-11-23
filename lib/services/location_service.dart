import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../data/models/venue.dart';

class LocationService {
  Future<Position> getCurrentLocation() async {
    return await Geolocator.getCurrentPosition();
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Check if a point is inside a polygon using ray casting algorithm
  bool isPointInPolygon(
      double latitude, double longitude, List<LatLng> polygon) {
    if (polygon.length < 3) return false;

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

    return inside;
  }

  bool isAtVenue(
      Position current, double targetLat, double targetLong, double targetAlt) {
    return isAtVenueWithTolerance(
        current, targetLat, targetLong, targetAlt, 100.0, 50.0);
  }

  bool isAtVenueWithTolerance(
      Position current,
      double targetLat,
      double targetLong,
      double targetAlt,
      double horizontalRadius,
      double verticalTolerance,
      {List<LatLng>? polygonCorners}) {
    // 2. Check Vertical Distance (Altitude) first
    double verticalDifference = (current.altitude - targetAlt).abs();
    bool altitudeMatch = verticalDifference <= verticalTolerance;

    // 1. Check Horizontal Distance
    bool horizontalMatch;
    String horizontalMethod;

    if (polygonCorners != null && polygonCorners.length >= 3) {
      // Use polygon checking
      horizontalMatch =
          isPointInPolygon(current.latitude, current.longitude, polygonCorners);
      horizontalMethod = 'Polygon (${polygonCorners.length} corners)';
    } else {
      // Use circular radius checking
      double distance = Geolocator.distanceBetween(
          current.latitude, current.longitude, targetLat, targetLong);
      horizontalMatch = distance <= horizontalRadius;
      horizontalMethod =
          'Radius ${distance.toStringAsFixed(1)}m (max: ${horizontalRadius.toStringAsFixed(0)}m)';
    }

    debugPrint('📍 Location Debug:');
    debugPrint('   Method: $horizontalMethod');
    debugPrint('   Current: ${current.latitude}, ${current.longitude}');
    debugPrint('   Target: $targetLat, $targetLong');
    debugPrint('   Horizontal match: ${horizontalMatch ? "✓" : "✗"}');
    debugPrint(
        '   Altitude diff: ${verticalDifference.toStringAsFixed(1)}m (max: ${verticalTolerance.toStringAsFixed(0)}m)');
    debugPrint('   Current alt: ${current.altitude.toStringAsFixed(1)}m');
    debugPrint('   Target alt: ${targetAlt.toStringAsFixed(1)}m');
    debugPrint('   Altitude match: ${altitudeMatch ? "✓" : "✗"}');

    return horizontalMatch && altitudeMatch;
  }
}
