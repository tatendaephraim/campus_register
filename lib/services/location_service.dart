import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<Position?> getCurrentLocation() async {
    final hasPermission = await _handlePermission();
    if (!hasPermission) return null;

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  bool isWithinRange(Position? current, double targetLat, double targetLon, [double radius = 100.0]) {
  if (current == null) return false;
  final distance = Geolocator.distanceBetween(
  current.latitude,
  current.longitude,
  targetLat,
  targetLon,
  );
  return distance <= radius;
  }

  Future<bool> _handlePermission() async {
  bool locationService = await Geolocator.isLocationServiceEnabled();
  if (!locationService) return false;

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
  permission = await Geolocator.requestPermission();
  if (permission == LocationPermission.denied) return false;
  }
  if (permission == LocationPermission.deniedForever) return false;
  return true;
  }
}