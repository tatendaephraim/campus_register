import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/attendance_record.dart';
import '../../data/repositories/attendance_repository.dart';

class DataLogScreen extends StatefulWidget {
  const DataLogScreen({super.key});

  @override
  State<DataLogScreen> createState() => _DataLogScreenState();
}

class _DataLogScreenState extends State<DataLogScreen> {
  final AttendanceRepository _repository = AttendanceRepository();
  List<AttendanceRecord> _records = [];
  bool _isLoading = true;
  String _filterType = 'All'; // All, CHECK-IN, CHECK-OUT
  String? _filterVenue;
  String? _filterUser;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    try {
      final records = await _repository.getAllAttendance();
      final count = await _repository.getTotalCount();
      setState(() {
        _records = records;
        _totalCount = count;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading records: $e')),
        );
      }
    }
  }

  List<AttendanceRecord> get _filteredRecords {
    return _records.where((record) {
      if (_filterType != 'All' && record.type != _filterType) return false;
      if (_filterVenue != null && record.venueName != _filterVenue) {
        return false;
      }
      if (_filterUser != null && record.name != _filterUser) return false;
      return true;
    }).toList();
  }

  Set<String> get _uniqueVenues {
    return _records.map((r) => r.venueName).toSet();
  }

  Set<String> get _uniqueUsers {
    return _records.map((r) => r.name).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredRecords = _filteredRecords;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Data Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportToCSV,
            tooltip: 'Export to CSV',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecords,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'clear') {
                _confirmClearAll();
              } else if (value == 'stats') {
                _showStats();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'stats',
                child: Row(
                  children: [
                    Icon(Icons.bar_chart),
                    SizedBox(width: 8),
                    Text('Statistics'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Clear All', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(theme),
          _buildSummaryCard(filteredRecords, theme),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredRecords.isEmpty
                    ? _buildEmptyState()
                    : _buildRecordsList(filteredRecords),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'All', label: Text('All')),
                    ButtonSegment(value: 'CHECK-IN', label: Text('In')),
                    ButtonSegment(value: 'CHECK-OUT', label: Text('Out')),
                  ],
                  selected: {_filterType},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() => _filterType = newSelection.first);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _filterVenue,
                  decoration: const InputDecoration(
                    labelText: 'Venue',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('All Venues')),
                    ..._uniqueVenues.map((venue) =>
                        DropdownMenuItem(value: venue, child: Text(venue))),
                  ],
                  onChanged: (value) => setState(() => _filterVenue = value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _filterUser,
                  decoration: const InputDecoration(
                    labelText: 'User',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('All Users')),
                    ..._uniqueUsers.map((user) =>
                        DropdownMenuItem(value: user, child: Text(user))),
                  ],
                  onChanged: (value) => setState(() => _filterUser = value),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(List<AttendanceRecord> records, ThemeData theme) {
    final checkIns = records.where((r) => r.type == 'CHECK-IN').length;
    final checkOuts = records.where((r) => r.type == 'CHECK-OUT').length;

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
                'Total', _totalCount.toString(), Icons.receipt_long, theme),
            _buildStatItem(
                'Showing', records.length.toString(), Icons.filter_list, theme),
            _buildStatItem(
                'Check-Ins', checkIns.toString(), Icons.login, theme),
            _buildStatItem(
                'Check-Outs', checkOuts.toString(), Icons.logout, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, ThemeData theme) {
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
              fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No attendance records',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Records will appear here after attendance is marked',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsList(List<AttendanceRecord> records) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        return _buildRecordCard(record);
      },
    );
  }

  Widget _buildRecordCard(AttendanceRecord record) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');
    final isCheckIn = record.type == 'CHECK-IN';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isCheckIn ? Colors.green[100] : Colors.red[100],
          child: Icon(
            isCheckIn ? Icons.login : Icons.logout,
            color: isCheckIn ? Colors.green[700] : Colors.red[700],
            size: 20,
          ),
        ),
        title: Text(
          record.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              record.venueName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              '${dateFormat.format(record.timestamp)} at ${timeFormat.format(record.timestamp)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Chip(
          label: Text(
            record.type,
            style: TextStyle(
              fontSize: 11,
              color: isCheckIn ? Colors.green[700] : Colors.red[700],
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: isCheckIn ? Colors.green[50] : Colors.red[50],
          padding: EdgeInsets.zero,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDetailRow('Venue', record.venueName, Icons.location_city),
                if (record.venueDescription != null)
                  _buildDetailRow('Description', record.venueDescription!,
                      Icons.description),
                _buildDetailRow('User Name', record.name, Icons.person),
                _buildDetailRow('Type', record.type, Icons.event),
                const Divider(),
                _buildDetailRow(
                  'Location',
                  'Lat: ${record.latitude.toStringAsFixed(6)}, Lon: ${record.longitude.toStringAsFixed(6)}',
                  Icons.pin_drop,
                ),
                _buildDetailRow(
                  'Altitude',
                  '${record.altitude.toStringAsFixed(1)}m',
                  Icons.terrain,
                ),
                _buildDetailRow(
                  'Floor',
                  'Floor ${record.estimatedFloor}',
                  Icons.stairs,
                ),
                const Divider(),
                _buildDetailRow(
                  'Timestamp',
                  '${dateFormat.format(record.timestamp)} ${timeFormat.format(record.timestamp)}',
                  Icons.access_time,
                ),
                _buildDetailRow('Record ID', '#${record.id}', Icons.tag),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _deleteRecord(record),
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToCSV() async {
    try {
      final path = await _repository.exportToCSV();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to: $path'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _deleteRecord(AttendanceRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Record'),
        content: Text('Delete attendance record for ${record.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _repository.deleteRecord(record.id!);
      if (!mounted) return;
      _loadRecords();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Record deleted')),
      );
    }
  }

  Future<void> _confirmClearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Records'),
        content: const Text(
          'This will permanently delete all attendance records. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _repository.clearAllRecords();
      if (!mounted) return;
      _loadRecords();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All records cleared')),
      );
    }
  }

  void _showStats() {
    final venueStats = <String, int>{};
    final userStats = <String, int>{};

    for (var record in _records) {
      venueStats[record.venueName] = (venueStats[record.venueName] ?? 0) + 1;
      userStats[record.name] = (userStats[record.name] ?? 0) + 1;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Statistics'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'By Venue',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ...venueStats.entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key),
                        Chip(label: Text(e.value.toString())),
                      ],
                    ),
                  )),
              const SizedBox(height: 16),
              const Text(
                'By User',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ...userStats.entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key),
                        Chip(label: Text(e.value.toString())),
                      ],
                    ),
                  )),
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
}
