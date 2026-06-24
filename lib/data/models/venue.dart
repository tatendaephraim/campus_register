class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
      };

  factory LatLng.fromJson(Map<String, dynamic> json) => LatLng(
        (json['latitude'] as num).toDouble(),
        (json['longitude'] as num).toDouble(),
      );
}

class Venue {
  final String id;
  final String name;
  final double latitude; // Center or first corner
  final double longitude; // Center or first corner
  final double altitude;
  final double horizontalRadius; // in meters (used if no polygon)
  final double verticalTolerance; // in meters
  final String? description;
  final List<LatLng>? polygonCorners; // Building corners (optional)

  Venue({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    this.horizontalRadius = 100.0,
    this.verticalTolerance = 50.0,
    this.description,
    this.polygonCorners,
  });

  Venue copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    double? altitude,
    double? horizontalRadius,
    double? verticalTolerance,
    String? description,
    List<LatLng>? polygonCorners,
  }) {
    return Venue(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      horizontalRadius: horizontalRadius ?? this.horizontalRadius,
      verticalTolerance: verticalTolerance ?? this.verticalTolerance,
      description: description ?? this.description,
      polygonCorners: polygonCorners ?? this.polygonCorners,
    );
  }

  bool get hasPolygon => polygonCorners != null && polygonCorners!.length >= 3;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'altitude': altitude,
        'horizontalRadius': horizontalRadius,
        'verticalTolerance': verticalTolerance,
        'description': description,
        'polygonCorners': polygonCorners?.map((p) => p.toJson()).toList(),
      };

  factory Venue.fromJson(Map<String, dynamic> json) {
    List<LatLng>? corners;
    if (json['polygonCorners'] != null) {
      corners = (json['polygonCorners'] as List)
          .map((c) => LatLng.fromJson(c as Map<String, dynamic>))
          .toList();
    }

    return Venue(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      altitude: (json['altitude'] as num).toDouble(),
      horizontalRadius: (json['horizontalRadius'] as num?)?.toDouble() ?? 100.0,
      verticalTolerance:
          (json['verticalTolerance'] as num?)?.toDouble() ?? 50.0,
      description: json['description'] as String?,
      polygonCorners: corners,
    );
  }
}
