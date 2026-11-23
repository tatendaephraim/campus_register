import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/attendance_provider.dart';
import '../../data/models/venue.dart';
import '../../services/location_service.dart';
import 'venue_map_screen.dart';
import 'venue_map_editor.dart';
import 'data_log_screen.dart';

class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() =>
      _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        title: const Text('Admin Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionHeader('Venue Management', Icons.location_city),
          const SizedBox(height: 12),
          ...state.availableVenues
              .map((venue) => _buildVenueCard(venue, theme)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _createVenueWithMap(),
            icon: const Icon(Icons.map),
            label: const Text('Create with Map'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _showAddVenueDialog(context, theme),
            icon: const Icon(Icons.edit_note),
            label: const Text('Create Manually'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionHeader('Data & Reports', Icons.assessment),
          const SizedBox(height: 12),
          _buildSettingsTile(
            icon: Icons.receipt_long,
            title: 'Attendance Data Log',
            subtitle: 'View all attendance records',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DataLogScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          _buildSectionHeader('Account Settings', Icons.person),
          const SizedBox(height: 12),
          _buildSettingsTile(
            icon: Icons.notifications,
            title: 'Notifications',
            subtitle: 'Manage attendance alerts',
            onTap: () {},
          ),
          _buildSettingsTile(
            icon: Icons.cloud_upload,
            title: 'Data Sync',
            subtitle: 'Configure Google Sheets sync',
            onTap: () {},
          ),
          _buildSettingsTile(
            icon: Icons.security,
            title: 'Security',
            subtitle: 'Biometric and permissions',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVenueCard(Venue venue, ThemeData theme) {
    final isSelected =
        ref.watch(attendanceProvider).currentVenue?.id == venue.id;

    return Card(
      elevation: isSelected ? 4 : 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.location_on,
            color: isSelected
                ? Colors.white
                : theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          venue.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSelected ? theme.colorScheme.primary : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (venue.description != null) ...[
              const SizedBox(height: 4),
              Text(venue.description!),
            ],
            const SizedBox(height: 8),
            Text(
              '${venue.latitude.toStringAsFixed(6)}, ${venue.longitude.toStringAsFixed(6)}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            Text(
              venue.hasPolygon
                  ? 'Alt: ${venue.altitude.toStringAsFixed(1)}m | Polygon: ${venue.polygonCorners!.length} corners'
                  : 'Alt: ${venue.altitude.toStringAsFixed(1)}m | Radius: ${venue.horizontalRadius.toStringAsFixed(0)}m',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'delete') {
              _confirmDelete(venue);
            } else if (value == 'edit') {
              _showEditVenueDialog(context, venue, theme);
            } else if (value == 'view_map') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VenueMapScreen(venue: venue),
                ),
              );
            } else if (value == 'edit_map') {
              _editVenueWithMap(venue);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view_map',
              child: Row(
                children: [
                  Icon(Icons.map, size: 20),
                  SizedBox(width: 8),
                  Text('View on Map'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'edit_map',
              child: Row(
                children: [
                  Icon(Icons.edit_location, size: 20),
                  SizedBox(width: 8),
                  Text('Edit with Map'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('Edit Manually'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  void _showAddVenueDialog(BuildContext context, ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) => AddVenueDialog(
        onAddVenue: (venue) {
          ref.read(attendanceProvider.notifier).addVenue(venue);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${venue.name} added successfully')),
          );
        },
      ),
    );
  }

  void _showEditVenueDialog(
      BuildContext context, Venue venue, ThemeData theme) {
    final nameController = TextEditingController(text: venue.name);
    final descController = TextEditingController(text: venue.description ?? '');
    final latController =
        TextEditingController(text: venue.latitude.toString());
    final lonController =
        TextEditingController(text: venue.longitude.toString());
    final altController =
        TextEditingController(text: venue.altitude.toString());
    final radiusController =
        TextEditingController(text: venue.horizontalRadius.toString());
    final toleranceController =
        TextEditingController(text: venue.verticalTolerance.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Venue'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Venue Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: latController,
                decoration: const InputDecoration(labelText: 'Latitude'),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lonController,
                decoration: const InputDecoration(labelText: 'Longitude'),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: altController,
                decoration: const InputDecoration(labelText: 'Altitude (m)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: radiusController,
                decoration:
                    const InputDecoration(labelText: 'Horizontal Radius (m)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: toleranceController,
                decoration:
                    const InputDecoration(labelText: 'Vertical Tolerance (m)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final updatedVenue = venue.copyWith(
                name: nameController.text,
                description:
                    descController.text.isEmpty ? null : descController.text,
                latitude: double.parse(latController.text),
                longitude: double.parse(lonController.text),
                altitude: double.parse(altController.text),
                horizontalRadius: double.parse(radiusController.text),
                verticalTolerance: double.parse(toleranceController.text),
              );

              ref.read(attendanceProvider.notifier).removeVenue(venue.id);
              ref.read(attendanceProvider.notifier).addVenue(updatedVenue);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Venue updated successfully')),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Venue venue) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Venue'),
        content: Text('Are you sure you want to delete "${venue.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(attendanceProvider.notifier).removeVenue(venue.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Venue deleted')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _createVenueWithMap() async {
    final venue = await Navigator.push<Venue>(
      context,
      MaterialPageRoute(
        builder: (context) => const VenueMapEditor(),
      ),
    );

    if (venue != null && mounted) {
      // Show dialog to enter name and description
      _showNameDescriptionDialog(context, venue);
    }
  }

  Future<void> _editVenueWithMap(Venue venue) async {
    final updatedVenue = await Navigator.push<Venue>(
      context,
      MaterialPageRoute(
        builder: (context) => VenueMapEditor(venue: venue),
      ),
    );

    if (updatedVenue != null && mounted) {
      // Update with original name but new coordinates/polygon
      final finalVenue = Venue(
        id: venue.id,
        name: venue.name,
        latitude: updatedVenue.latitude,
        longitude: updatedVenue.longitude,
        altitude: updatedVenue.altitude,
        horizontalRadius: updatedVenue.horizontalRadius,
        verticalTolerance: updatedVenue.verticalTolerance,
        description: venue.description,
        polygonCorners: updatedVenue.polygonCorners,
      );

      ref.read(attendanceProvider.notifier).removeVenue(venue.id);
      ref.read(attendanceProvider.notifier).addVenue(finalVenue);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${venue.name} updated successfully')),
      );
    }
  }

  void _showNameDescriptionDialog(BuildContext context, Venue venue) {
    final nameController = TextEditingController(text: venue.name);
    final descController = TextEditingController(text: venue.description ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Venue Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Venue Name',
                hintText: 'e.g., Main Campus, Lecture Hall A',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Additional details',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a venue name')),
                );
                return;
              }

              final finalVenue = Venue(
                id: venue.id,
                name: nameController.text.trim(),
                latitude: venue.latitude,
                longitude: venue.longitude,
                altitude: venue.altitude,
                horizontalRadius: venue.horizontalRadius,
                verticalTolerance: venue.verticalTolerance,
                description: descController.text.trim().isEmpty
                    ? null
                    : descController.text.trim(),
                polygonCorners: venue.polygonCorners,
              );

              ref.read(attendanceProvider.notifier).addVenue(finalVenue);
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('${finalVenue.name} added successfully')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// Stateful dialog for adding venues with polygon support
class AddVenueDialog extends StatefulWidget {
  final Function(Venue) onAddVenue;

  const AddVenueDialog({super.key, required this.onAddVenue});

  @override
  State<AddVenueDialog> createState() => _AddVenueDialogState();
}

class _AddVenueDialogState extends State<AddVenueDialog> {
  final nameController = TextEditingController();
  final descController = TextEditingController();
  final latController = TextEditingController();
  final lonController = TextEditingController();
  final altController = TextEditingController();
  final radiusController = TextEditingController(text: '100');
  final toleranceController = TextEditingController(text: '50');

  final List<LatLng> polygonCorners = [];
  bool usePolygon = false;
  final LocationService _locationService = LocationService();
  bool _isLoadingLocation = false;

  @override
  void dispose() {
    nameController.dispose();
    descController.dispose();
    latController.dispose();
    lonController.dispose();
    altController.dispose();
    radiusController.dispose();
    toleranceController.dispose();
    super.dispose();
  }

  void _addCorner() {
    final latController = TextEditingController();
    final lonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Corner Point'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoadingLocation
                          ? null
                          : () async {
                              setDialogState(() => _isLoadingLocation = true);
                              try {
                                final position =
                                    await _locationService.getCurrentLocation();
                                latController.text =
                                    position.latitude.toString();
                                lonController.text =
                                    position.longitude.toString();
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text('Failed to get location: $e')),
                                  );
                                }
                              } finally {
                                setDialogState(
                                    () => _isLoadingLocation = false);
                              }
                            },
                      icon: _isLoadingLocation
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location, size: 20),
                      label: Text(
                          _isLoadingLocation ? 'Getting...' : 'Use Current'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Or enter manually:',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: latController,
                decoration: const InputDecoration(
                  labelText: 'Latitude',
                  hintText: '-1.927196',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lonController,
                decoration: const InputDecoration(
                  labelText: 'Longitude',
                  hintText: '30.140773',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (latController.text.isNotEmpty &&
                    lonController.text.isNotEmpty) {
                  setState(() {
                    polygonCorners.add(LatLng(
                      double.parse(latController.text),
                      double.parse(lonController.text),
                    ));
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Venue/Class'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Venue Name *',
                hintText: 'e.g., Lecture Hall B',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'e.g., CS Building - Floor 5',
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Location Coordinates',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isLoadingLocation
                  ? null
                  : () async {
                      setState(() => _isLoadingLocation = true);
                      try {
                        final position =
                            await _locationService.getCurrentLocation();
                        latController.text = position.latitude.toString();
                        lonController.text = position.longitude.toString();
                        altController.text =
                            position.altitude.toStringAsFixed(1);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Failed to get location: $e')),
                          );
                        }
                      } finally {
                        setState(() => _isLoadingLocation = false);
                      }
                    },
              icon: _isLoadingLocation
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.my_location),
              label: Text(_isLoadingLocation
                  ? 'Getting Location...'
                  : 'Use Current Location'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Or enter manually:',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: latController,
              decoration: const InputDecoration(
                labelText: 'Center Latitude *',
                hintText: '-1.927196',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lonController,
              decoration: const InputDecoration(
                labelText: 'Center Longitude *',
                hintText: '30.140773',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: altController,
              decoration: const InputDecoration(
                labelText: 'Altitude (m) *',
                hintText: '1500',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: usePolygon,
                  onChanged: (value) => setState(() => usePolygon = value!),
                ),
                const Expanded(
                  child: Text(
                    'Use Polygon (mark building corners)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (!usePolygon) ...[
              const SizedBox(height: 12),
              TextField(
                controller: radiusController,
                decoration: const InputDecoration(
                  labelText: 'Horizontal Radius (m)',
                  hintText: '100',
                ),
                keyboardType: TextInputType.number,
              ),
            ] else ...[
              const SizedBox(height: 8),
              if (polygonCorners.isEmpty)
                const Text(
                  'No corners added yet. Add at least 3 corners.',
                  style: TextStyle(fontSize: 12, color: Colors.orange),
                )
              else ...[
                Text(
                  '${polygonCorners.length} corners added:',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                ...polygonCorners.asMap().entries.map((entry) {
                  final index = entry.key;
                  final corner = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${index + 1}. ${corner.latitude.toStringAsFixed(6)}, ${corner.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              size: 18, color: Colors.red),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () =>
                              setState(() => polygonCorners.removeAt(index)),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _addCorner,
                icon: const Icon(Icons.add),
                label: const Text('Add Corner'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: toleranceController,
              decoration: const InputDecoration(
                labelText: 'Vertical Tolerance (m)',
                hintText: '50',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (nameController.text.isEmpty ||
                latController.text.isEmpty ||
                lonController.text.isEmpty ||
                altController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please fill required fields')),
              );
              return;
            }

            if (usePolygon && polygonCorners.length < 3) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Polygon needs at least 3 corners')),
              );
              return;
            }

            final venue = Venue(
              id: 'venue_${DateTime.now().millisecondsSinceEpoch}',
              name: nameController.text,
              description:
                  descController.text.isEmpty ? null : descController.text,
              latitude: double.parse(latController.text),
              longitude: double.parse(lonController.text),
              altitude: double.parse(altController.text),
              horizontalRadius: double.parse(radiusController.text),
              verticalTolerance: double.parse(toleranceController.text),
              polygonCorners: usePolygon ? polygonCorners : null,
            );

            widget.onAddVenue(venue);
            Navigator.pop(context);
          },
          child: const Text('Add Venue'),
        ),
      ],
    );
  }
}
