import 'package:http/http.dart' as http;

import 'database_helper.dart';
import 'attendance_record.dart';
import 'course.dart';
import 'student.dart';
import 'teacher.dart';

/// A service to handle syncing attendance records to Google Sheets.
class GoogleSheetsSyncService {
  final dbHelper = DatabaseHelper.instance;

  /// Fetches the teacher's Google Sheet URL from the database.
  Future<String?> _getSheetUrl(int courseId) async {
    final db = await dbHelper.database;
    // This query joins courses and teachers to find the sheet URL for a given course.
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT T.google_sheet_url
      FROM teachers T
      JOIN courses C ON T.id = C.teacher_id
      WHERE C.id = ?
    ''', [courseId]);

    if (result.isNotEmpty) {
      return result.first['google_sheet_url'] as String?;
    }
    return null;
  }

  /// Syncs a single attendance record to the teacher's Google Sheet.
  Future<void> syncRecord({
    required AttendanceRecord record,
    required Student student,
    required Course course,
  }) async {
    final sheetUrl = await _getSheetUrl(course.id!);
    if (sheetUrl == null || sheetUrl.isEmpty) {
      print('⚠️ Google Sheet URL not found for this course. Skipping sync.');
      return;
    }

    try {
      print('☁️ Syncing to Google Sheets...');
      final response = await http.post(
        Uri.parse(sheetUrl),
        body: {
          'timestamp': record.timestamp.toIso8601String(),
          'name': student.name,
          'status': record.status,
          'venue': course.name, // Using course name as the 'venue'
          'description': course.schoolName ?? '',
          'coords': record.location,
          'latitude': record.latitude.toString(),
          'longitude': record.longitude.toString(),
          'altitude': '${record.altitude.toStringAsFixed(1)}m',
          'floor':
              'Floor 0', // Placeholder as floor calculation is not implemented
          'verifier': 'Biometric_Success',
        },
      ).timeout(const Duration(seconds: 15));

      // A 302 redirect is a common success response from Google Apps Script
      if (response.statusCode == 200 || response.statusCode == 302) {
        print('✅ Successfully synced to Google Sheets.');
      } else {
        print(
            '❌ Google Sheets sync failed with status: ${response.statusCode}');
        print('❌ Response: ${response.body}');
      }
    } catch (e) {
      // The sync is a background task, so we don't want to show an error
      // to the user if it fails. We just log it.
      print('⚠️ Google Sheets sync connection error: $e');
    }
  }
}
