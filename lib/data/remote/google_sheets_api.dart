import 'package:http/http.dart' as http;
import '../models/attendance_record.dart';

class GoogleSheetsApi {
  // Your current deployment URL
  final String _url =
      'https://script.google.com/macros/s/AKfycbwJ3DUDmoC0FMjw9AA0lzDh3yo32OjjyALMue73B4K05YkUQxwT2Tu5jpxfkb3e2jEF/exec';

  Future<bool> syncRecord(AttendanceRecord record) async {
    try {
      print('📤 Starting Google Sheets sync...');
      print('🔗 URL: $_url');

      // Use the toSyncData method which has all the fields
      final syncData = record.toSyncData();

      print('📊 Data to send:');
      syncData.forEach((key, value) {
        print('  $key: $value');
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
          print('⏱️ Request timed out after 10 seconds');
          throw Exception('Request timeout');
        },
      );

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');
      print('📥 Response headers: ${response.headers}');

      // Google Apps Script returns 302 redirect - this is NORMAL and means success
      if (response.statusCode == 302) {
        print(
            "✅ Sync Successful (302 redirect): ${record.name} at ${record.venueName}");
        return true;
      }

      if (response.statusCode == 200) {
        if (response.body.contains('Success') ||
            response.body.contains('success')) {
          print("✅ Sync Successful: ${record.name} at ${record.venueName}");
          return true;
        } else {
          print("⚠️ Unexpected response: ${response.body}");
          // Even if body is unexpected, status 200 means it was received
          print("✅ Accepting as success due to 200 status");
          return true;
        }
      } else {
        print("❌ Sync Failed with status: ${response.statusCode}");
        print("❌ Response: ${response.body}");
        return false;
      }
    } catch (e, stackTrace) {
      print("⚠️ Connection Error: $e");
      print("⚠️ Stack trace: $stackTrace");
      return false;
    }
  }
}
