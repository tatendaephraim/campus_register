import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import 'venue.dart' as app_models;
import 'venue_repository.dart';
import 'ui/design_tokens.dart';

class VenueEditorScreen extends StatefulWidget {
  final app_models.Venue? venue;
  final int? organizationId;
  const VenueEditorScreen({super.key, this.venue, this.organizationId});

  @override
  State<VenueEditorScreen> createState() => _VenueEditorScreenState();
}

class _VenueEditorScreenState extends State<VenueEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _venueRepo = VenueRepository();
  final Completer<GoogleMapController> _mapController = Completer();

  String _category = 'classroom'; // classroom | office | staff_room

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
    if (widget.venue != null) {
      _nameController.text = widget.venue!.name;
      _altitude = widget.venue!.altitude;
      _category = widget.venue!.category;
      if (widget.venue!.polygonCorners != null) {
        _polygonCorners.addAll(
          widget.venue!.polygonCorners!.map((c) => LatLng(c.latitude, c.longitude))
        );
      }
      _zoomToVenue();
    } else {
      _initCurrentLocation();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _zoomToVenue() async {
    try {
      if (_polygonCorners.isNotEmpty) {
        final controller = await _mapController.future;
        controller.animateCamera(CameraUpdate.newLatLngZoom(_polygonCorners.first, 18));
      }
    } catch (_) {}
  }

  Future<void> _initCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 18));
      setState(() {
        _altitude = pos.altitude;
      });
    } catch (e) {
      print("Could not get current location on open: $e");
    }
  }

  Future<void> _captureAltitude() async {
    setState(() => _isCapturingAltitude = true);
    try {
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      final finalAltitude = position.altitude;
      setState(() {
        _altitude = finalAltitude;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Venue altitude captured: ${_altitude.toStringAsFixed(1)}m'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not capture altitude: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
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
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not get GPS location for corner: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
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
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
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
        id: widget.venue?.id, // Preserve original ID!
        organizationId: widget.venue?.organizationId ?? widget.organizationId,
        name: _nameController.text,
        category: _category,
        latitude: centerLat,
        longitude: centerLng,
        altitude: _altitude,
        radius: 50.0, // Default horizontal tolerance radius
        verticalTolerance: 12.0, // Height limit tolerance set to 12 meters
        polygonCorners: modelCorners,
      );

      final savedVenue = await _venueRepo.upsertVenue(newVenue);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Venue volumetric 3D geofence saved successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(savedVenue); // Return the saved Venue!
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
            tooltip: 'Save Venue',
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
                    color: AppColors.slate950.withOpacity(0.8),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.mdR),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md + 2, vertical: AppSpace.sm),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.grid_3x3_rounded,
                            color: theme.colorScheme.secondary,
                            size: 18,
                          ),
                          const SizedBox(width: AppSpace.sm),
                          Text(
                            'CORNERS: ${_polygonCorners.length} (MIN 3)',
                            style: AppType.data(context, color: Colors.white, weight: FontWeight.w600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.md),
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate800 : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
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
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Category selector ──────────────────────────────
                      _buildCategorySelector(),
                      const SizedBox(height: AppSpace.md),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: _categoryLabel(),
                          prefixIcon: Icon(_categoryIcon()),
                        ),
                        validator: (value) => value!.isEmpty ? 'Please enter a name' : null,
                      ),
                      if (_polygonCorners.isNotEmpty) ...[
                        const SizedBox(height: AppSpace.md),
                        Container(
                          padding: const EdgeInsets.all(AppSpace.md),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.slate900 : AppColors.slate100,
                            borderRadius: AppRadius.mdR,
                            border: Border.all(color: theme.colorScheme.secondary.withOpacity(0.2), width: 1),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.center_focus_strong_rounded,
                                color: theme.colorScheme.secondary,
                                size: 20,
                              ),
                              const SizedBox(width: AppSpace.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Centroid coordinates (live)',
                                      style: AppType.body(context, fontSize: 11.5, weight: FontWeight.w700, color: AppColors.textSecondary(isDark), letterSpacing: 0.4),
                                    ),
                                    const SizedBox(height: 2),
                                    Builder(
                                      builder: (context) {
                                        double latSum = 0;
                                        double lngSum = 0;
                                        for (var corner in _polygonCorners) {
                                          latSum += corner.latitude;
                                          lngSum += corner.longitude;
                                        }
                                        final centerLat = latSum / _polygonCorners.length;
                                        final centerLng = lngSum / _polygonCorners.length;
                                        return Text(
                                          '${centerLat.toStringAsFixed(6)}, ${centerLng.toStringAsFixed(6)}',
                                          style: AppType.data(context, fontSize: 14, weight: FontWeight.w600, color: AppColors.textPrimary(isDark)),
                                        );
                                      }
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpace.md),
                      Container(
                        padding: const EdgeInsets.all(AppSpace.md),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.slate900 : AppColors.slate100,
                          borderRadius: AppRadius.mdR,
                          border: Border.all(color: AppColors.indigo.withOpacity(0.15), width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Floor altitude',
                                    style: AppType.body(context, fontSize: 11.5, weight: FontWeight.w700, color: AppColors.textSecondary(isDark), letterSpacing: 0.4),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_altitude.toStringAsFixed(1)}m',
                                    style: AppType.data(context, fontSize: 19, weight: FontWeight.w600, color: AppColors.textPrimary(isDark)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '-8m to +12m volumetric tolerance band',
                                    style: AppType.body(context, fontSize: 11.5, color: AppColors.textTertiary(isDark)),
                                  ),
                                ],
                              ),
                            ),
                            _isCapturingAltitude
                                ? const CircularProgressIndicator()
                                : ElevatedButton.icon(
                                    onPressed: _captureAltitude,
                                    icon: const Icon(Icons.height_rounded, size: 18),
                                    label: const Text('Capture floor'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: AppRadius.smR),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpace.md),
                      _isCapturingCornerGps
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton.icon(
                              onPressed: _addCornerAtGps,
                              icon: const Icon(Icons.gps_fixed_rounded, size: 18),
                              label: const Text('Add corner at GPS location'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: AppRadius.mdR),
                              ),
                            ),
                      const SizedBox(height: AppSpace.md),
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
                              label: const Text('Undo last'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: AppRadius.smR),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpace.md),
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
                              label: const Text('Clear all'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.dangerDark,
                                side: const BorderSide(color: AppColors.dangerDark),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: AppRadius.smR),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Category helpers ──────────────────────────────────────────────────────

  static const _categories = [
    ('classroom', 'Classroom', Icons.class_rounded),
    ('office',    'Office',    Icons.business_center_rounded),
    ('staff_room','Staff Room',Icons.meeting_room_rounded),
  ];

  Widget _buildCategorySelector() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'VENUE TYPE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary(theme.brightness == Brightness.dark),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: _categories.map((cat) {
            final (key, label, icon) = cat;
            final isSelected = _category == key;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primary.withOpacity(0.06),
                    borderRadius: AppRadius.mdR,
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.primary.withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: AppRadius.mdR,
                    onTap: () => setState(() => _category = key),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        children: [
                          Icon(
                            icon,
                            size: 20,
                            color: isSelected ? Colors.white : theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : theme.colorScheme.primary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _categoryLabel() {
    switch (_category) {
      case 'office':     return 'Office name (e.g. Principal\'s Office)';
      case 'staff_room': return 'Staff room name (e.g. Staff Room A)';
      default:           return 'Classroom name (e.g. Room 101)';
    }
  }

  IconData _categoryIcon() {
    switch (_category) {
      case 'office':     return Icons.business_center_rounded;
      case 'staff_room': return Icons.meeting_room_rounded;
      default:           return Icons.class_rounded;
    }
  }
}
