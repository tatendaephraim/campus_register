import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lottie/lottie.dart' hide Marker;
import 'package:flutter_svg/flutter_svg.dart';

import 'venue.dart' as app_models;
import 'venue_repository.dart';
import 'venue_editor_screen.dart';
import 'ui/design_tokens.dart';

class ManageVenuesScreen extends StatefulWidget {
  final int? organizationId;
  const ManageVenuesScreen({super.key, this.organizationId});

  @override
  State<ManageVenuesScreen> createState() => _ManageVenuesScreenState();
}

class _ManageVenuesScreenState extends State<ManageVenuesScreen> {
  final _venueRepo = VenueRepository();
  List<app_models.Venue> _venues = [];
  bool _isLoading = true;

  // Pagination & Map Visibility state
  final Set<int> _expandedMapVenueIds = {};
  int _currentPage = 0;
  static const int _itemsPerPage = 5;

  @override
  void initState() {
    super.initState();
    _loadVenues();
  }

  Future<void> _loadVenues() async {
    setState(() => _isLoading = true);
    try {
      final list = await _venueRepo.getAllVenues(organizationId: widget.organizationId);
      if (mounted) {
        setState(() {
          _venues = list;
          // Guard page bounds on refresh/load
          final maxPage = (list.length / _itemsPerPage).ceil() - 1;
          if (_currentPage > maxPage) {
            _currentPage = maxPage.clamp(0, double.infinity).toInt();
          }
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
        builder: (context) => VenueEditorScreen(organizationId: widget.organizationId),
      ),
    );
    if (result != null) {
      _loadVenues();
    }
  }

  Future<void> _editVenue(app_models.Venue venue) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VenueEditorScreen(venue: venue, organizationId: widget.organizationId),
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
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, _venues.length);
    final paginatedVenues = _venues.isEmpty ? <app_models.Venue>[] : _venues.sublist(startIndex, endIndex);
    final totalPages = (_venues.length / _itemsPerPage).ceil();

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
                'Venues Manager',
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
                            Colors.black.withOpacity(0.45),
                            Colors.black.withOpacity(0.1),
                            Colors.black.withOpacity(0.6),
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
                              color: Colors.white.withOpacity(0.8),
                              weight: FontWeight.w700,
                              fontSize: 10,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Configure office & classroom geofence boundaries',
                            style: AppType.body(
                              context,
                              fontSize: 12.5,
                              color: Colors.white.withOpacity(0.7),
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
                          'assets/lottie/venue.json',
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
                          'Tap the "+" button below to set up your first office or classroom geofence boundary.',
                          textAlign: TextAlign.center,
                          style: AppType.body(context, fontSize: 13, color: AppColors.textSecondary(isDark)),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              // Venues List
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final venue = paginatedVenues[index];
                    return _buildVenueCard(context, venue, isDark, theme);
                  },
                  childCount: paginatedVenues.length,
                ),
              ),

              // Pagination Controls
              if (totalPages > 1)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.lg, horizontal: AppSpace.lg),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Previous Page button
                        TextButton.icon(
                          onPressed: _currentPage > 0
                              ? () => setState(() => _currentPage--)
                              : null,
                          icon: const Icon(Icons.chevron_left_rounded),
                          label: const Text('Previous'),
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.primary,
                          ),
                        ),
                        // Page indicator
                        Text(
                          'Page ${_currentPage + 1} of $totalPages',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary(isDark),
                          ),
                        ),
                        // Next Page button
                        TextButton.icon(
                          onPressed: _currentPage < totalPages - 1
                              ? () => setState(() => _currentPage++)
                              : null,
                          icon: const Icon(Icons.chevron_right_rounded),
                          label: const Text('Next'),
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
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
        label: const Text('Add Venue / Office'),
        elevation: 4,
      ),
    );
  }

  Widget _buildVenueCard(BuildContext context, app_models.Venue venue, bool isDark, ThemeData theme) {
    final center = LatLng(venue.latitude, venue.longitude);
    final bool showPolygon = venue.hasPolygon;
    final isMapVisible = _expandedMapVenueIds.contains(venue.id);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.sm),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgR,
        side: BorderSide(color: AppColors.border(isDark), width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.md, AppSpace.xs, AppSpace.xs),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  child: Icon(
                    venue.category == 'classroom'
                        ? Icons.school_rounded
                        : venue.category == 'staff_room'
                            ? Icons.meeting_room_rounded
                            : Icons.business_center_rounded,
                    color: theme.colorScheme.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        venue.name,
                        style: AppType.display(context, fontSize: 15, weight: FontWeight.w700, color: AppColors.textPrimary(isDark)),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          _buildCategoryChip(venue.category, theme),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              showPolygon
                                  ? '${venue.polygonCorners!.length}-pt polygon'
                                  : 'Circle (r = ${venue.radius.toStringAsFixed(0)}m)',
                              style: AppType.body(context, fontSize: 11, color: AppColors.textSecondary(isDark), weight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.slate400, size: 20),
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
                          Icon(Icons.edit_note_rounded, color: theme.colorScheme.primary, size: 18),
                          const SizedBox(width: AppSpace.sm),
                          const Text('Edit Details', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 18),
                          const SizedBox(width: AppSpace.sm),
                          const Text('Delete Venue', style: TextStyle(color: AppColors.danger, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.layers_rounded, size: 13, color: AppColors.textTertiary(isDark)),
                    const SizedBox(width: 4),
                    Text(
                      'Alt: ${venue.altitude.toStringAsFixed(1)}m (±${venue.verticalTolerance > 0 ? venue.verticalTolerance : 12.0}m)',
                      style: AppType.body(context, fontSize: 11.5, color: AppColors.textSecondary(isDark)),
                    ),
                  ],
                ),
                // Toggle Map button
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      if (isMapVisible) {
                        _expandedMapVenueIds.remove(venue.id);
                      } else {
                        _expandedMapVenueIds.add(venue.id!);
                      }
                    });
                  },
                  icon: Icon(
                    isMapVisible ? Icons.map_outlined : Icons.map_rounded,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  label: Text(
                    isMapVisible ? 'Hide Map' : 'View Map',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          if (isMapVisible) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 120,
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
                          fillColor: theme.colorScheme.primary.withOpacity(0.12),
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
                          fillColor: theme.colorScheme.primary.withOpacity(0.12),
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
          ] else
            const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category, ThemeData theme) {
    Color color;
    IconData icon;
    String label;
    switch (category) {
      case 'office':
        color = Colors.indigo;
        icon = Icons.business_center_rounded;
        label = 'OFFICE';
        break;
      case 'staff_room':
        color = Colors.teal;
        icon = Icons.meeting_room_rounded;
        label = 'STAFF ROOM';
        break;
      default:
        color = Colors.blue;
        icon = Icons.class_rounded;
        label = 'CLASSROOM';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}
