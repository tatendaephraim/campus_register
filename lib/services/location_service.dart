import 'package:geolocator/geolocator.dart';

import '../domain/attendance_policy.dart';

enum LocationProblem {
  serviceOff('Location services are turned off.'),
  denied('Location permission was denied.'),
  deniedForever('Location permission is blocked. Enable it in settings.'),
  noFix('No position fix was obtained in time.');

  const LocationProblem(this.message);
  final String message;
}

class LocationReading {
  const LocationReading.fix(PositionSample this.position) : problem = null;
  const LocationReading.failed(LocationProblem this.problem) : position = null;

  final PositionSample? position;
  final LocationProblem? problem;
}

class LocationService {
  Future<LocationReading> read() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationReading.failed(LocationProblem.serviceOff);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationReading.failed(LocationProblem.deniedForever);
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        return const LocationReading.failed(LocationProblem.denied);
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 20),
        ),
      );
      return LocationReading.fix(
        PositionSample(
          latitude: p.latitude,
          longitude: p.longitude,
          accuracyM: p.accuracy,
          timestamp: p.timestamp,
          isMocked: p.isMocked,
        ),
      );
    } on LocationServiceDisabledException {
      return const LocationReading.failed(LocationProblem.serviceOff);
    } catch (_) {
      return const LocationReading.failed(LocationProblem.noFix);
    }
  }
}
