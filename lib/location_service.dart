import 'dart:async';
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

  /// Check if a point is inside a polygon using ray casting algorithm.
  bool isPointInPolygon(double latitude, double longitude, List<LatLng> polygon) {
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
}
