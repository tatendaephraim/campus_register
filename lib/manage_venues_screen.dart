import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lottie/lottie.dart' hide Marker;
import 'package:flutter_svg/flutter_svg.dart';

import 'venue.dart' as app_models;
import 'venue_repository.dart';
import 'venue_editor_screen.dart';
import 'ui/design_tokens.dart';

class ManageVenuesScreen extends StatefulWidget {
  const ManageVenuesScreen({super.key});

  @override
  State<ManageVenuesScreen> createState() => _ManageVenuesScreenState();
}

class _ManageVenuesScreenState extends State<ManageVenuesScreen> {
  final _venueRepo = VenueRepository();
  List<app_models.Venue> _venues = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVenues();
  }

  Future<void> _loadVenues() async {
    setState(() => _isLoading = true);
    try {
      final list = await _venueRepo.getAllVenues();
      if (mounted) {
        setState(() {
          _venues = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading venues: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addVenue() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const VenueEditorScreen(),
      ),
    );
    if (result != null) {
      _loadVenues();
    }
  }

  Future<void> _editVenue(app_models.Venue venue) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VenueEditorScreen(venue: venue),
      ),
    );
    if (result != null) {
      _loadVenues();
    }
  }

  Future<void> _confirmDeleteVenue(app_models.Venue venue) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 28),
            SizedBox(width: AppSpace.sm),
            Text('Delete Venue'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${venue.name}"?\n\n'
          'Any courses currently linked to this venue will no longer have active geofence boundaries.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _venueRepo.deleteVenue(venue.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Venue deleted successfully'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting venue: $e'),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        _loadVenues();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [AppColors.slate900, AppColors.slate800]
                : [AppColors.slate50, const Color(0xFFEEF2F6)],
          ),
        ),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 150.0,
              pinned: true,
              backgroundColor: isDark ? AppColors.slate950 : theme.colorScheme.primary,
              foregroundColor: Colors.white,
              title: Text(
                'Classrooms Manager',
                style: AppType.display(context, fontSize: 18, weight: FontWeight.w700, color: Colors.white),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    SvgPicture.asset(
                      'assets/images/banner.svg',
                      fit: BoxFit.cover,
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.45),
                            Colors.black.withValues(alpha: 0.1),
                            Colors.black.withValues(alpha: 0.6),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpace.xl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '3D VOLUMETRIC GEOFENCES',
                            style: AppType.body(
                              context,
                              color: Colors.white.withValues(alpha: 0.8),
                              weight: FontWeight.w700,
                              fontSize: 10,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Configure classroom boundaries and altitudes',
                            style: AppType.body(
                              context,
                              fontSize: 12.5,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_venues.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.xxl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Lottie.asset(
                          'assets/lottie/register.json',
                          height: 180,
                          width: 180,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.room_preferences_rounded,
                            size: 64,
                            color: AppColors.slate400,
                          ),
                        ),
                        const SizedBox(height: AppSpace.xl),
                        Text(
                          'No venues configured yet',
                          style: AppType.display(
                            context,
                            fontSize: 17,
                            weight: FontWeight.w600,
                            color: AppColors.textPrimary(isDark),
                          ),
                        ),
                        const SizedBox(height: AppSpace.sm),
                        Text(
                          'Tap the "+" button below to set up your first classroom geofence boundary.',
                          textAlign: TextAlign.center,
                          style: AppType.body(context, fontSize: 13, color: AppColors.textSecondary(isDark)),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final venue = _venues[index];
                    return _buildVenueCard(context, venue, isDark, theme);
                  },
                  childCount: _venues.length,
                ),
              ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 100.0),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addVenue,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Add Classroom'),
        elevation: 4,
      ),
    );
  }

  Widget _buildVenueCard(BuildContext context, app_models.Venue venue, bool isDark, ThemeData theme) {
    final center = LatLng(venue.latitude, venue.longitude);
    final bool showPolygon = venue.hasPolygon;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.sm + 2),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.xlR,
        side: BorderSide(color: AppColors.border(isDark), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.sm, AppSpace.sm),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                  child: Icon(Icons.room_rounded, color: theme.colorScheme.primary, size: 20),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        venue.name,
                        style: AppType.display(context, fontSize: 16, weight: FontWeight.w700, color: AppColors.textPrimary(isDark)),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        showPolygon
                            ? '${venue.polygonCorners!.length}-point polygon geofence'
                            : 'Circular geofence (r = ${venue.radius.toStringAsFixed(0)}m)',
                        style: AppType.body(context, fontSize: 12, color: AppColors.textSecondary(isDark), weight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.slate400),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.mdR),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editVenue(venue);
                    } else if (value == 'delete') {
                      _confirmDeleteVenue(venue);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_note_rounded, color: theme.colorScheme.primary, size: 20),
                          const SizedBox(width: AppSpace.sm),
                          const Text('Edit Details'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                          SizedBox(width: AppSpace.sm),
                          Text('Delete Venue', style: TextStyle(color: AppColors.danger)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.xs),
            child: Row(
              children: [
                Icon(Icons.layers_rounded, size: 14, color: AppColors.textTertiary(isDark)),
                const SizedBox(width: 6),
                Text(
                  'Altitude: ${venue.altitude.toStringAsFixed(1)}m (Tolerance: +${venue.verticalTolerance > 0 ? venue.verticalTolerance : 12.0}m)',
                  style: AppType.body(context, fontSize: 12.5, color: AppColors.textSecondary(isDark)),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          SizedBox(
            height: 130,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: center, zoom: 17.0),
              liteModeEnabled: true,
              markers: {
                Marker(
                  markerId: MarkerId(venue.id.toString()),
                  position: center,
                )
              },
              circles: showPolygon
                  ? {}
                  : {
                      Circle(
                        circleId: CircleId(venue.id.toString()),
                        center: center,
                        radius: venue.radius,
                        fillColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                        strokeColor: theme.colorScheme.primary,
                        strokeWidth: 2,
                      )
                    },
              polygons: showPolygon
                  ? {
                      Polygon(
                        polygonId: PolygonId(venue.id.toString()),
                        points: venue.polygonCorners!
                            .map((c) => LatLng(c.latitude, c.longitude))
                            .toList(),
                        fillColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                        strokeColor: theme.colorScheme.primary,
                        strokeWidth: 2,
                      )
                    }
                  : {},
              scrollGesturesEnabled: false,
              zoomGesturesEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              myLocationButtonEnabled: false,
            ),
          ),
        ],
      ),
    );
  }
}
