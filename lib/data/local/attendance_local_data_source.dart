import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/attendance_record.dart';
import 'database_helper.dart';

class AttendanceLocalDataSource {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Save to SQLite database
  Future<int> saveToDatabase(AttendanceRecord record) async {
    return await _dbHelper.insertAttendance(record);
  }

  // Get all records from database
  Future<List<AttendanceRecord>> getAllRecords() async {
    return await _dbHelper.getAllAttendance();
  }

  // Get recent records
  Future<List<AttendanceRecord>> getRecentRecords(int limit) async {
    return await _dbHelper.getRecentAttendance(limit);
  }

  // Get records by venue
  Future<List<AttendanceRecord>> getRecordsByVenue(String venueName) async {
    return await _dbHelper.getAttendanceByVenue(venueName);
  }

  // Get records by user
  Future<List<AttendanceRecord>> getRecordsByUser(String userName) async {
    return await _dbHelper.getAttendanceByUser(userName);
  }

  // Get records by date range
  Future<List<AttendanceRecord>> getRecordsByDateRange(
      DateTime start, DateTime end) async {
    return await _dbHelper.getAttendanceByDateRange(start, end);
  }

  // Get total count
  Future<int> getTotalCount() async {
    return await _dbHelper.getTotalCount();
  }

  // Backup to CSV (optional, for export)
  Future<void> saveToCSV(AttendanceRecord record) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/attendance_log.csv');

      final exists = await file.exists();
      if (!exists) {
        await file.writeAsString(
            'Name,Type,Timestamp,Venue,Description,Location,Latitude,Longitude,Altitude,Floor\n');
      }

      final line =
          '${record.name},${record.type},${record.timestamp},${record.venueName},'
          '"${record.venueDescription ?? ""}",${record.location},'
          '${record.latitude},${record.longitude},${record.altitude},${record.estimatedFloor}\n';
      await file.writeAsString(line, mode: FileMode.append);
      debugPrint('📄 Backup to CSV completed');
    } catch (e) {
      debugPrint('⚠️ CSV backup failed: $e');
    }
  }

  // Export all records to CSV
  Future<String> exportToCSV() async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${directory.path}/attendance_export_$timestamp.csv');

    final records = await getAllRecords();

    final buffer = StringBuffer();
    buffer.writeln(
        'ID,Name,Type,Timestamp,Venue,Description,Location,Latitude,Longitude,Altitude,Floor');

    for (var record in records) {
      buffer.writeln(
          '${record.id},${record.name},${record.type},${record.timestamp},'
          '${record.venueName},"${record.venueDescription ?? ""}",${record.location},'
          '${record.latitude},${record.longitude},${record.altitude},${record.estimatedFloor}');
    }

    await file.writeAsString(buffer.toString());
    debugPrint('📊 Exported ${records.length} records to ${file.path}');
    return file.path;
  }

  // Delete a record
  Future<void> deleteRecord(int id) async {
    await _dbHelper.deleteAttendance(id);
  }

  // Clear all records
  Future<void> clearAllRecords() async {
    await _dbHelper.deleteAllAttendance();
  }
}
