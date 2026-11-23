import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../data/models/venue.dart' as app_models;
import '../../services/location_service.dart';

class VenueMapEditor extends StatefulWidget {
  final app_models.Venue? venue; // null for new venue

  const VenueMapEditor({super.key, this.venue});

  @override
  State<VenueMapEditor> createState() => _VenueMapEditorState();
}

class _VenueMapEditorState extends State<VenueMapEditor> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polygon> _polygons = {};
  final Set<Circle> _circles = {};
  final List<app_models.LatLng> _polygonCorners = [];

  late app_models.LatLng _centerLocation;
  late double _altitude;
  bool _isPolygonMode = true;
  double _radius = 100.0;
  bool _isLoadingLocation = false;

  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    if (widget.venue != null) {
      // Editing existing venue
      _centerLocation = app_models.LatLng(
        widget.venue!.latitude,
        widget.venue!.longitude,
      );
      _altitude = widget.venue!.altitude;
      _isPolygonMode = widget.venue!.hasPolygon;
      if (_isPolygonMode) {
        _polygonCorners.addAll(widget.venue!.polygonCorners!);
      } else {
        _radius = widget.venue!.horizontalRadius;
      }
    } else {
      // New venue - use default location
      _centerLocation = const app_models.LatLng(-1.927196, 30.140773);
      _altitude = 1500.0;
    }
    _updateMapObjects();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.venue == null
            ? 'Create Venue'
            : 'Edit ${widget.venue!.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveVenue,
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target:
                  LatLng(_centerLocation.latitude, _centerLocation.longitude),
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
            },
            onTap: _isPolygonMode ? _onMapTap : null,
            onLongPress: !_isPolygonMode ? _onMapLongPress : null,
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _isPolygonMode ? 'Polygon Mode' : 'Radius Mode',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Switch(
                          value: _isPolygonMode,
                          onChanged: (value) {
                            setState(() {
                              _isPolygonMode = value;
                              _polygonCorners.clear();
                              _updateMapObjects();
                            });
                          },
                        ),
                      ],
                    ),
                    const Divider(),
                    if (_isPolygonMode) ...[
                      Text(
                          'Tap on map to add corners (${_polygonCorners.length} added)'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isLoadingLocation ? null : _addCornerAtCurrentLocation,
                            icon: const Icon(Icons.gps_fixed, size: 18),
                            label: const Text('Add GPS Corner'),
                          ),
                          ElevatedButton.icon(
                            onPressed: _polygonCorners.isEmpty
                                ? null
                                : _undoLastCorner,
                            icon: const Icon(Icons.undo, size: 18),
                            label: const Text('Undo'),
                          ),
                          ElevatedButton.icon(
                            onPressed:
                                _polygonCorners.isEmpty ? null : _clearCorners,
                            icon: const Icon(Icons.clear, size: 18),
                            label: const Text('Clear'),
                          ),
                        ],
                      ),
                    ] else ...[
                      const Text('Long-press to set center'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Radius: '),
                          Expanded(
                            child: Slider(
                              value: _radius,
                              min: 20,
                              max: 500,
                              divisions: 48,
                              label: '${_radius.toStringAsFixed(0)}m',
                              onChanged: (value) {
                                setState(() {
                                  _radius = value;
                                  _updateMapObjects();
                                });
                              },
                            ),
                          ),
                          Text('${_radius.toStringAsFixed(0)}m'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'current_location',
              onPressed: _isLoadingLocation ? null : _useCurrentLocation,
              child: _isLoadingLocation
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }

  void _onMapTap(LatLng position) {
    setState(() {
      _polygonCorners
          .add(app_models.LatLng(position.latitude, position.longitude));
      _updateMapObjects();
    });
  }

  void _onMapLongPress(LatLng position) {
    setState(() {
      _centerLocation =
          app_models.LatLng(position.latitude, position.longitude);
      _updateMapObjects();
    });
  }

  void _undoLastCorner() {
    if (_polygonCorners.isNotEmpty) {
      setState(() {
        _polygonCorners.removeLast();
        _updateMapObjects();
      });
    }
  }

  void _clearCorners() {
    setState(() {
      _polygonCorners.clear();
      _updateMapObjects();
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      final position = await _locationService.getCurrentLocation();
      setState(() {
        _centerLocation =
            app_models.LatLng(position.latitude, position.longitude);
        _altitude = position.altitude;
        _isLoadingLocation = false;
      });

      // Animate camera to new location
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
      );

      _updateMapObjects();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location updated!')),
        );
      }
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e')),
        );
      }
    }
  }

  Future<void> _addCornerAtCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      final position = await _locationService.getCurrentLocation();
      setState(() {
        _polygonCorners.add(app_models.LatLng(position.latitude, position.longitude));
        _isLoadingLocation = false;
        _updateMapObjects();
      });

      // Animate camera to new corner
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added corner #${_polygonCorners.length} at GPS!')),
        );
      }
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e')),
        );
      }
    }
  }

  void _updateMapObjects() {
    _markers.clear();
    _polygons.clear();
    _circles.clear();

    // Center marker
    _markers.add(
      Marker(
        markerId: const MarkerId('center'),
        position: LatLng(_centerLocation.latitude, _centerLocation.longitude),
        infoWindow: const InfoWindow(title: 'Venue Center'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        draggable: !_isPolygonMode,
        onDragEnd: (newPosition) {
          setState(() {
            _centerLocation = app_models.LatLng(
              newPosition.latitude,
              newPosition.longitude,
            );
          });
        },
      ),
    );

    if (_isPolygonMode && _polygonCorners.isNotEmpty) {
      // Polygon corners
      for (int i = 0; i < _polygonCorners.length; i++) {
        _markers.add(
          Marker(
            markerId: MarkerId('corner_$i'),
            position: LatLng(
                _polygonCorners[i].latitude, _polygonCorners[i].longitude),
            infoWindow: InfoWindow(title: 'Corner ${i + 1}'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange),
            draggable: true,
            onDragEnd: (newPosition) {
              setState(() {
                _polygonCorners[i] = app_models.LatLng(
                  newPosition.latitude,
                  newPosition.longitude,
                );
                _updateMapObjects();
              });
            },
          ),
        );
      }

      // Draw polygon if at least 3 corners
      if (_polygonCorners.length >= 3) {
        _polygons.add(
          Polygon(
            polygonId: const PolygonId('venue_polygon'),
            points: _polygonCorners
                .map((c) => LatLng(c.latitude, c.longitude))
                .toList(),
            strokeColor: Colors.blue,
            strokeWidth: 3,
            fillColor: Colors.blue.withOpacity(0.2),
          ),
        );
      }
    } else if (!_isPolygonMode) {
      // Radius circle
      _circles.add(
        Circle(
          circleId: const CircleId('venue_radius'),
          center: LatLng(_centerLocation.latitude, _centerLocation.longitude),
          radius: _radius,
          strokeColor: Colors.green,
          strokeWidth: 2,
          fillColor: Colors.green.withOpacity(0.2),
        ),
      );
    }

    setState(() {});
  }

  void _saveVenue() {
    if (_isPolygonMode && _polygonCorners.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Polygon needs at least 3 corners')),
      );
      return;
    }

    final venue = app_models.Venue(
      id: widget.venue?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: widget.venue?.name ?? 'New Venue',
      latitude: _centerLocation.latitude,
      longitude: _centerLocation.longitude,
      altitude: _altitude,
      horizontalRadius: _isPolygonMode ? 50.0 : _radius,
      verticalTolerance: widget.venue?.verticalTolerance ?? 50.0,
      description: widget.venue?.description,
      polygonCorners: _isPolygonMode ? _polygonCorners : null,
    );

    Navigator.pop(context, venue);
  }
}
