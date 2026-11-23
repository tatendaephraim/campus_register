import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:campus_register/venue.dart';
import 'package:campus_register/location_service.dart';
import 'package:campus_register/services/altitude_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock Sensors Method Channel to avoid MissingPluginException
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/sensors/method'),
    (MethodCall methodCall) async {
      if (methodCall.method == 'setBarometerSamplingPeriod') {
        return null;
      }
      return null;
    },
  );

  group('3D Volumetric Geofence & Location Validation Tests', () {
    final locationService = LocationService();

    test('isPointInPolygon correctly identifies points inside and outside polygon', () {
      // Define a simple square polygon (4 corners)
      final polygon = [
        const LatLng(0.0, 0.0),
        const LatLng(0.0, 10.0),
        const LatLng(10.0, 10.0),
        const LatLng(10.0, 0.0),
      ];

      // Point inside the polygon
      expect(locationService.isPointInPolygon(5.0, 5.0, polygon), isTrue);

      // Point outside the polygon
      expect(locationService.isPointInPolygon(15.0, 5.0, polygon), isFalse);

      // Point exactly on corner/edge check (usually outside or boundaries vary, but definitely outside bounds should be false)
      expect(locationService.isPointInPolygon(-1.0, -1.0, polygon), isFalse);
    });

    test('isPointInPolygon returns false for polygons with less than 3 corners', () {
      final incompletePolygon = [
        const LatLng(0.0, 0.0),
        const LatLng(0.0, 10.0),
      ];
      expect(locationService.isPointInPolygon(5.0, 5.0, incompletePolygon), isFalse);
    });

    test('pressureToAltitude converts pressure (hPa) to correct altitude using barometric formula', () {
      final altitudeService = AltitudeService.instance;

      // At sea level pressure (1013.25 hPa), altitude should be 0
      expect(altitudeService.pressureToAltitude(1013.25), closeTo(0.0, 0.1));

      // Standard atmospheric pressure drops with height. At 900 hPa, it should be around 1000m.
      final altAt900 = altitudeService.pressureToAltitude(900.0);
      expect(altAt900, greaterThan(900.0));
      expect(altAt900, lessThan(1100.0));

      // Extreme values
      expect(altitudeService.pressureToAltitude(0.0), 0.0);
      expect(altitudeService.pressureToAltitude(-50.0), 0.0);
    });

    test('getCombinedAltitude handles cases with and without barometer data', () {
      final altitudeService = AltitudeService.instance;

      // By default without barometer stream events in testing environment, it should fallback to GPS only.
      expect(altitudeService.getCombinedAltitude(1520.0), 1520.0);
    });
  });
}
