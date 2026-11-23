import 'dart:math' as math;

/// Where a position estimate lies relative to the fence, once its reported
/// uncertainty is taken into account.
enum FenceResult {
  /// The whole uncertainty disc is inside the fence.
  inside,

  /// The whole uncertainty disc is outside the fence.
  outside,

  /// The disc crosses the boundary, so the fix cannot settle the question.
  uncertain,
}

const double _earthRadiusM = 6371008.8;

/// Great-circle distance in metres (haversine).
double haversineMetres(double lat1, double lon1, double lat2, double lon2) {
  const toRad = math.pi / 180;
  final sinLat = math.sin((lat2 - lat1) * toRad / 2);
  final sinLon = math.sin((lon2 - lon1) * toRad / 2);
  final a =
      sinLat * sinLat +
      math.cos(lat1 * toRad) * math.cos(lat2 * toRad) * sinLon * sinLon;
  return 2 * _earthRadiusM * math.asin(math.sqrt(math.min(1.0, a)));
}

/// Three-valued circular geofence test. [accuracyM] is the radius the operating
/// system reports around the fix (68% confidence on Android).
FenceResult classifyFence({
  required double distanceM,
  required double accuracyM,
  required double radiusM,
}) {
  if (distanceM + accuracyM <= radiusM) return FenceResult.inside;
  if (distanceM - accuracyM > radiusM) return FenceResult.outside;
  return FenceResult.uncertain;
}
