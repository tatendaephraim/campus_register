import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import 'venue.dart' as app_models;
import 'venue_repository.dart';
import 'services/altitude_service.dart';

class VenueEditorScreen extends StatefulWidget {
  const VenueEditorScreen({super.key});

  @override
  State<VenueEditorScreen> createState() => _VenueEditorScreenState();
}

class _VenueEditorScreenState extends State<VenueEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _venueRepo = VenueRepository();
  final Completer<GoogleMapController> _mapController = Completer();

  static const _initialCameraPosition = CameraPosition(
    target: LatLng(-1.927196, 30.140773), // Default campus location
    zoom: 17.0,
  );

  final List<LatLng> _polygonCorners = [];
  double _altitude = 1500.0;
  bool _isCapturingAltitude = false;
  bool _isCapturingCornerGps = false;

  @override
  void initState() {
    super.initState();
    _initCurrentLocation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _initCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 18));
      setState(() {
        _altitude = AltitudeService.instance.getCombinedAltitude(pos.altitude);
      });
    } catch (e) {
      print("Could not get current location on open: $e");
    }
  }

  Future<void> _captureAltitude() async {
    setState(() => _isCapturingAltitude = true);
    try {
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      final finalAltitude = AltitudeService.instance.getCombinedAltitude(position.altitude);
      setState(() {
        _altitude = finalAltitude;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Classroom altitude captured: ${_altitude.toStringAsFixed(1)}m'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not capture altitude: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isCapturingAltitude = false);
    }
  }

  Future<void> _addCornerAtGps() async {
    setState(() => _isCapturingCornerGps = true);
    try {
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      final latLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _polygonCorners.add(latLng);
      });
      final controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newLatLng(latLng));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added corner #${_polygonCorners.length} at GPS: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not get GPS location for corner: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isCapturingCornerGps = false);
    }
  }

  Future<void> _saveVenue() async {
    if (_formKey.currentState!.validate()) {
      if (_polygonCorners.length < 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Under system rules, a class geofence must have at least 3 corners marked.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Calculate centroid of the polygon for the main latitude/longitude
      double latSum = 0;
      double lngSum = 0;
      for (var corner in _polygonCorners) {
        latSum += corner.latitude;
        lngSum += corner.longitude;
      }
      final centerLat = latSum / _polygonCorners.length;
      final centerLng = lngSum / _polygonCorners.length;

      // Convert to our model's LatLng
      final modelCorners = _polygonCorners.map((c) => app_models.LatLng(c.latitude, c.longitude)).toList();

      final newVenue = app_models.Venue(
        name: _nameController.text,
        latitude: centerLat,
        longitude: centerLng,
        altitude: _altitude,
        radius: 50.0, // Default horizontal tolerance radius
        verticalTolerance: 5.0, // Height limit enforced to 5 meters
        polygonCorners: modelCorners,
      );

      await _venueRepo.upsertVenue(newVenue);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Venue volumetric 3D geofence saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Volumetric Geofence'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle_outline_rounded, size: 28),
            onPressed: _saveVenue,
            tooltip: 'Save Classroom',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  mapType: MapType.hybrid,
                  initialCameraPosition: _initialCameraPosition,
                  onMapCreated: (GoogleMapController controller) {
                    _mapController.complete(controller);
                  },
                  onTap: (position) {
                    setState(() {
                      _polygonCorners.add(position);
                    });
                  },
                  markers: _polygonCorners
                      .asMap()
                      .entries
                      .map((entry) => Marker(
                            markerId: MarkerId('corner_${entry.key}'),
                            position: entry.value,
                            infoWindow: InfoWindow(title: 'Corner ${entry.key + 1}'),
                            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                          ))
                      .toSet(),
                  polygons: _polygonCorners.length >= 3
                      ? {
                          Polygon(
                            polygonId: const PolygonId('venue_polygon'),
                            points: _polygonCorners,
                            strokeColor: theme.colorScheme.primary,
                            strokeWidth: 3,
                            fillColor: theme.colorScheme.primary.withOpacity(0.2),
                          )
                        }
                      : {},
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: Card(
                    color: Colors.black.withOpacity(0.75),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.grid_3x3_rounded,
                            color: theme.colorScheme.secondary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Corners: ${_polygonCorners.length} (Min 3)',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Classroom Name',
                      prefixIcon: const Icon(Icons.meeting_room_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    ),
                    validator: (value) => value!.isEmpty ? 'Please enter a classroom name' : null,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Floor Altitude: ${_altitude.toStringAsFixed(1)}m',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Height Limit: 5m Ceiling',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _isCapturingAltitude
                            ? const CircularProgressIndicator()
                            : ElevatedButton.icon(
                                onPressed: _captureAltitude,
                                icon: const Icon(Icons.height_rounded, size: 18),
                                label: const Text('Capture Floor'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _isCapturingCornerGps
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          onPressed: _addCornerAtGps,
                          icon: const Icon(Icons.gps_fixed_rounded, size: 18),
                          label: const Text('Add Corner at GPS Location'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _polygonCorners.isEmpty
                              ? null
                              : () {
                                  setState(() {
                                    _polygonCorners.removeLast();
                                  });
                                },
                          icon: const Icon(Icons.undo_rounded, size: 18),
                          label: const Text('Undo Last'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _polygonCorners.isEmpty
                              ? null
                              : () {
                                  setState(() {
                                    _polygonCorners.clear();
                                  });
                                },
                          icon: const Icon(Icons.clear_all_rounded, size: 18),
                          label: const Text('Clear All'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
