import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/attendance_record.dart';

class GoogleSheetsApi {
  // Your current deployment URL
  final String _url =
      'https://script.google.com/macros/s/AKfycbwJ3DUDmoC0FMjw9AA0lzDh3yo32OjjyALMue73B4K05YkUQxwT2Tu5jpxfkb3e2jEF/exec';

  Future<bool> syncRecord(AttendanceRecord record) async {
    try {
      debugPrint('📤 Starting Google Sheets sync...');
      debugPrint('🔗 URL: $_url');

      // Use the toSyncData method which has all the fields
      final syncData = record.toSyncData();

      debugPrint('📊 Data to send:');
      syncData.forEach((key, value) {
        debugPrint('  $key: $value');
      });

      final response = await http.post(
        Uri.parse(_url),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'name': syncData['Name'],
          'status': syncData['Type'],
          'timestamp': syncData['Timestamp'],
          'venue': syncData['Venue'],
          'description': syncData['Description'],
          'coords': syncData['Location'],
          'latitude': syncData['Latitude'],
          'longitude': syncData['Longitude'],
          'altitude': syncData['Altitude'],
          'floor': syncData['Floor'],
          'verifier': 'Biometric_Success',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⏱️ Request timed out after 10 seconds');
          throw Exception('Request timeout');
        },
      );

      debugPrint('📥 Response status: ${response.statusCode}');
      debugPrint('📥 Response body: ${response.body}');
      debugPrint('📥 Response headers: ${response.headers}');

      // Google Apps Script returns 302 redirect - this is NORMAL and means success
      if (response.statusCode == 302) {
        debugPrint(
            "✅ Sync Successful (302 redirect): ${record.name} at ${record.venueName}");
        return true;
      }

      if (response.statusCode == 200) {
        if (response.body.contains('Success') ||
            response.body.contains('success')) {
          debugPrint("✅ Sync Successful: ${record.name} at ${record.venueName}");
          return true;
        } else {
          debugPrint("⚠️ Unexpected response: ${response.body}");
          // Even if body is unexpected, status 200 means it was received
          debugPrint("✅ Accepting as success due to 200 status");
          return true;
        }
      } else {
        debugPrint("❌ Sync Failed with status: ${response.statusCode}");
        debugPrint("❌ Response: ${response.body}");
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint("⚠️ Connection Error: $e");
      debugPrint("⚠️ Stack trace: $stackTrace");
      return false;
    }
  }
}
