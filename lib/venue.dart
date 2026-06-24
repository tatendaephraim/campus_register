import 'dart:convert';

class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);

  Map<String, dynamic> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
      };

  factory LatLng.fromMap(Map<String, dynamic> map) => LatLng(
        (map['latitude'] as num).toDouble(),
        (map['longitude'] as num).toDouble(),
      );
}

/// Represents a physical venue with a 3D geofence boundary (polygon + altitude).
class Venue {
  final int? id;
  final String name;
  final double latitude; // Center point latitude
  final double longitude; // Center point longitude
  final double altitude; // Center point elevation (ground level)
  final double radius; // Horizontal tolerance (radius in meters if polygon is empty)
  final double verticalTolerance; // Vertical tolerance / height limit (meters, default: 5.0)
  final List<LatLng>? polygonCorners; // List of at least 3 coordinates defining the class area

  Venue({
    this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.radius,
    required this.verticalTolerance,
    this.polygonCorners,
  });

  bool get hasPolygon => polygonCorners != null && polygonCorners!.length >= 3;

  /// Creates a [Venue] instance from a database map.
  factory Venue.fromMap(Map<String, dynamic> map) {
    List<LatLng>? corners;
    if (map['polygon_corners'] != null && (map['polygon_corners'] as String).isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(map['polygon_corners'] as String);
      corners = decoded.map((c) => LatLng.fromMap(c as Map<String, dynamic>)).toList();
    }

    return Venue(
      id: map['id'] as int?,
      name: map['name'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      altitude: (map['altitude'] as num?)?.toDouble() ?? 1500.0,
      radius: (map['radius'] as num).toDouble(),
      verticalTolerance: (map['vertical_tolerance'] as num?)?.toDouble() ?? 5.0,
      polygonCorners: corners,
    );
  }

  /// Converts the [Venue] instance into a map for database insertion.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'radius': radius,
      'vertical_tolerance': verticalTolerance,
      'polygon_corners': polygonCorners != null ? jsonEncode(polygonCorners!.map((c) => c.toMap()).toList()) : null,
    };
  }
}
