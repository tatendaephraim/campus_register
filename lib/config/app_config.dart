import '../domain/attendance_policy.dart';

/// Build-time configuration, supplied with `--dart-define` or
/// `--dart-define-from-file`. Nothing site-specific or secret is hardcoded.
class AppConfig {
  static const String campusName = String.fromEnvironment(
    'CAMPUS_NAME',
    defaultValue: 'Demo campus',
  );

  static const String _lat = String.fromEnvironment('CAMPUS_LAT');
  static const String _lon = String.fromEnvironment('CAMPUS_LON');
  static const String _radius = String.fromEnvironment('CAMPUS_RADIUS_M');
  static const String _accuracy = String.fromEnvironment('MAX_ACCURACY_M');

  /// Google Apps Script `/exec` URL. Empty means "collect locally only".
  static const String syncUrl = String.fromEnvironment('SYNC_URL');

  /// Shared token checked by the server. It is extractable from the app binary
  /// and only keeps out casual traffic; see the README threat model.
  static const String syncToken = String.fromEnvironment('SYNC_TOKEN');

  static final AttendancePolicy policy = AttendancePolicy(
    latitude: _number('CAMPUS_LAT', _lat, -1.927196),
    longitude: _number('CAMPUS_LON', _lon, 30.140773),
    radiusM: _number('CAMPUS_RADIUS_M', _radius, 100),
    maxAccuracyM: _number('MAX_ACCURACY_M', _accuracy, 50),
  );

  /// Dart has no `double.fromEnvironment`. A bad value fails loudly instead of
  /// geofencing the wrong place.
  static double _number(String name, String raw, double fallback) {
    if (raw.isEmpty) return fallback;
    final value = double.tryParse(raw);
    if (value == null || !value.isFinite) {
      throw FormatException('$name is not a number', raw);
    }
    return value;
  }
}
