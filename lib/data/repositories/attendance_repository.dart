import 'package:supabase_flutter/supabase_flutter.dart';
import '../local/attendance_local_data_source.dart';
import '../remote/google_sheets_api.dart';
import '../models/attendance_record.dart';

class AttendanceRepository {
  final _localDataSource = AttendanceLocalDataSource();
  final _remoteApi = GoogleSheetsApi();
  final _supabase = Supabase.instance.client;

  // Save attendance with full SQLite support
  Future<bool> saveAttendance(AttendanceRecord record) async {
    try {
      print('💾 Saving attendance record...');

      // 1. Try saving to Supabase first if online
      AttendanceRecord? supabaseRecord;
      try {
        final map = record.toMap();
        if (record.id == null) {
          map.remove('id');
        }
        
        final response = await _supabase
            .from('attendance')
            .insert(map)
            .select()
            .single();
        
        supabaseRecord = AttendanceRecord.fromMap(response);
        print('✅ Synced attendance record to Supabase');
      } catch (e) {
        print('⚠️ Supabase attendance insert error: $e');
      }

      final recordToSave = supabaseRecord ?? record;

      // Save to SQLite database (primary storage)
      await _localDataSource.saveToDatabase(recordToSave);
      print('✅ Saved to SQLite database');

      // Backup to CSV (optional)
      await _localDataSource.saveToCSV(recordToSave);
      print('✅ Backed up to CSV');

      // Sync to Google Sheets (with proper error handling)
      print('☁️ Syncing to Google Sheets...');
      try {
        final syncSuccess = await _remoteApi.syncRecord(recordToSave);
        if (syncSuccess) {
          print('✅ Successfully synced to Google Sheets');
        } else {
          print('⚠️ Google Sheets sync failed (returned false)');
        }
      } catch (syncError) {
        print('⚠️ Google Sheets sync error: $syncError');
        // Don't fail the entire save if remote sync fails
      }

      return true;
    } catch (e) {
      print('❌ Failed to save attendance: $e');
      return false;
    }
  }

  // Get all attendance records
  Future<List<AttendanceRecord>> getAllAttendance() async {
    // Try Supabase first
    try {
      final List<dynamic> response = await _supabase
          .from('attendance')
          .select()
          .order('timestamp', ascending: false);
      
      final records = response.map((item) => AttendanceRecord.fromMap(item as Map<String, dynamic>)).toList();
      
      // Update local cache
      final dsHelper = _localDataSource;
      await dsHelper.clearAllRecords();
      for (var r in records) {
        await dsHelper.saveToDatabase(r);
      }
      return records;
    } catch (e) {
      print('⚠️ Supabase fetch all attendance logs error: $e');
    }

    return await _localDataSource.getAllRecords();
  }

  // Get recent attendance records
  Future<List<AttendanceRecord>> getRecentAttendance(int limit) async {
    // Try Supabase first
    try {
      final List<dynamic> response = await _supabase
          .from('attendance')
          .select()
          .order('timestamp', ascending: false)
          .limit(limit);
      
      final records = response.map((item) => AttendanceRecord.fromMap(item as Map<String, dynamic>)).toList();
      return records;
    } catch (e) {
      print('⚠️ Supabase fetch recent attendance logs error: $e');
    }

    return await _localDataSource.getRecentRecords(limit);
  }

  // Get attendance by venue
  Future<List<AttendanceRecord>> getAttendanceByVenue(String venueName) async {
    // Try Supabase first
    try {
      final List<dynamic> response = await _supabase
          .from('attendance')
          .select()
          .eq('venueName', venueName)
          .order('timestamp', ascending: false);
      
      final records = response.map((item) => AttendanceRecord.fromMap(item as Map<String, dynamic>)).toList();
      return records;
    } catch (e) {
      print('⚠️ Supabase fetch attendance by venue error: $e');
    }

    return await _localDataSource.getRecordsByVenue(venueName);
  }

  // Get attendance by user
  Future<List<AttendanceRecord>> getAttendanceByUser(String userName) async {
    // Try Supabase first
    try {
      final List<dynamic> response = await _supabase
          .from('attendance')
          .select()
          .eq('name', userName)
          .order('timestamp', ascending: false);
      
      final records = response.map((item) => AttendanceRecord.fromMap(item as Map<String, dynamic>)).toList();
      return records;
    } catch (e) {
      print('⚠️ Supabase fetch attendance by user error: $e');
    }

    return await _localDataSource.getRecordsByUser(userName);
  }

  // Get attendance by date range
  Future<List<AttendanceRecord>> getAttendanceByDateRange(
      DateTime start, DateTime end) async {
    // Try Supabase first
    try {
      final List<dynamic> response = await _supabase
          .from('attendance')
          .select()
          .gte('timestamp', start.toIso8601String())
          .lte('timestamp', end.toIso8601String())
          .order('timestamp', ascending: false);
      
      final records = response.map((item) => AttendanceRecord.fromMap(item as Map<String, dynamic>)).toList();
      return records;
    } catch (e) {
      print('⚠️ Supabase fetch attendance by date range error: $e');
    }

    return await _localDataSource.getRecordsByDateRange(start, end);
  }

  // Get total count
  Future<int> getTotalCount() async {
    // Try Supabase first
    try {
      final response = await _supabase
          .from('attendance')
          .select('id')
          .count(CountOption.exact);
      
      final count = response.count;
      return count;
    } catch (e) {
      print('⚠️ Supabase fetch total attendance count error: $e');
    }

    return await _localDataSource.getTotalCount();
  }

  // Export to CSV
  Future<String> exportToCSV() async {
    return await _localDataSource.exportToCSV();
  }

  // Delete record
  Future<void> deleteRecord(int id) async {
    // Try deleting from Supabase
    try {
      await _supabase
          .from('attendance')
          .delete()
          .eq('id', id);
      print('✅ Deleted attendance log from Supabase: ID=$id');
    } catch (e) {
      print('⚠️ Supabase delete attendance log error: $e');
    }

    await _localDataSource.deleteRecord(id);
  }

  // Clear all records
  Future<void> clearAllRecords() async {
    // Try deleting all from Supabase
    try {
      await _supabase
          .from('attendance')
          .delete()
          .neq('id', 0); // Deletes all records
      print('✅ Cleared all attendance logs from Supabase');
    } catch (e) {
      print('⚠️ Supabase clear attendance logs error: $e');
    }

    await _localDataSource.clearAllRecords();
  }
}
