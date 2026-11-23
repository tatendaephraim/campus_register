import 'package:http/http.dart' as http;
import '../models/attendance_record.dart';

class GoogleSheetsApi {
  final String _url = 'https://script.google.com/macros/s/YOUR_DEPLOYMENT_ID/exec'; // Replace

  Future<bool> syncRecord(AttendanceRecord record) async {
    try {
      final response = await http.post(
        Uri.parse(_url),
        body: {
          'name': record.name,
          'type': record.type,
          'timestamp': record.timestamp,
          'location': record.location,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}