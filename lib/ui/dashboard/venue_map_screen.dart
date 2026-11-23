import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../data/models/venue.dart' as app_models;

class VenueMapScreen extends StatefulWidget {
  final app_models.Venue venue;

  const VenueMapScreen({super.key, required this.venue});

  @override
  State<VenueMapScreen> createState() => _VenueMapScreenState();
}

class _VenueMapScreenState extends State<VenueMapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polygon> _polygons = {};
  final Set<Circle> _circles = {};

  @override
  void initState() {
    super.initState();
    _setupMapObjects();
  }

  void _setupMapObjects() {
    // Add center marker
    _markers.add(
      Marker(
        markerId: MarkerId('center_${widget.venue.id}'),
        position: LatLng(widget.venue.latitude, widget.venue.longitude),
        infoWindow: InfoWindow(
          title: widget.venue.name,
          snippet: widget.venue.description ?? 'Venue Center',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    );

    if (widget.venue.hasPolygon) {
      // Show polygon
      final polygonPoints = widget.venue.polygonCorners!
          .map((corner) => LatLng(corner.latitude, corner.longitude))
          .toList();

      _polygons.add(
        Polygon(
          polygonId: PolygonId('polygon_${widget.venue.id}'),
          points: polygonPoints,
          strokeColor: Colors.blue,
          strokeWidth: 3,
          fillColor: Colors.blue.withValues(alpha: 0.2),
        ),
      );

      // Add markers for corners
      for (int i = 0; i < widget.venue.polygonCorners!.length; i++) {
        final corner = widget.venue.polygonCorners![i];
        _markers.add(
          Marker(
            markerId: MarkerId('corner_${widget.venue.id}_$i'),
            position: LatLng(corner.latitude, corner.longitude),
            infoWindow: InfoWindow(title: 'Corner ${i + 1}'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange),
          ),
        );
      }
    } else {
      // Show radius circle
      _circles.add(
        Circle(
          circleId: CircleId('radius_${widget.venue.id}'),
          center: LatLng(widget.venue.latitude, widget.venue.longitude),
          radius: widget.venue.horizontalRadius,
          strokeColor: Colors.green,
          strokeWidth: 2,
          fillColor: Colors.green.withValues(alpha: 0.2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.venue.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showVenueInfo(),
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(widget.venue.latitude, widget.venue.longitude),
          zoom: 17.0,
        ),
        markers: _markers,
        polygons: _polygons,
        circles: _circles,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        mapType: MapType.hybrid,
        onMapCreated: (controller) {
          _mapController = controller;
          // Adjust camera to show all markers/polygon
          if (widget.venue.hasPolygon) {
            _fitPolygonBounds();
          }
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'map_type',
            onPressed: _toggleMapType,
            child: const Icon(Icons.layers),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'recenter',
            onPressed: _recenterMap,
            child: const Icon(Icons.center_focus_strong),
          ),
        ],
      ),
    );
  }

  MapType _currentMapType = MapType.hybrid;

  void _toggleMapType() {
    setState(() {
      _currentMapType = _currentMapType == MapType.normal
          ? MapType.hybrid
          : _currentMapType == MapType.hybrid
              ? MapType.satellite
              : MapType.normal;
    });
  }

  void _recenterMap() {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(widget.venue.latitude, widget.venue.longitude),
          zoom: 17.0,
        ),
      ),
    );
  }

  void _fitPolygonBounds() {
    if (!widget.venue.hasPolygon) return;

    final corners = widget.venue.polygonCorners!;
    if (corners.isEmpty) return;

    double minLat = corners.first.latitude;
    double maxLat = corners.first.latitude;
    double minLng = corners.first.longitude;
    double maxLng = corners.first.longitude;

    for (var corner in corners) {
      minLat = minLat < corner.latitude ? minLat : corner.latitude;
      maxLat = maxLat > corner.latitude ? maxLat : corner.latitude;
      minLng = minLng < corner.longitude ? minLng : corner.longitude;
      maxLng = maxLng > corner.longitude ? maxLng : corner.longitude;
    }

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        100, // padding
      ),
    );
  }

  void _showVenueInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.venue.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.venue.description != null) ...[
                Text(widget.venue.description!),
                const SizedBox(height: 16),
              ],
              _buildInfoRow('Center',
                  '${widget.venue.latitude.toStringAsFixed(6)}, ${widget.venue.longitude.toStringAsFixed(6)}'),
              _buildInfoRow(
                  'Altitude', '${widget.venue.altitude.toStringAsFixed(1)}m'),
              if (widget.venue.hasPolygon) ...[
                _buildInfoRow('Type',
                    'Polygon (${widget.venue.polygonCorners!.length} corners)'),
              ] else ...[
                _buildInfoRow('Radius',
                    '${widget.venue.horizontalRadius.toStringAsFixed(0)}m'),
              ],
              _buildInfoRow('Vertical Tolerance',
                  '±${widget.venue.verticalTolerance.toStringAsFixed(0)}m'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
