import '../local/attendance_local_data_source.dart';
import '../remote/google_sheets_api.dart';
import '../models/attendance_record.dart';

class AttendanceRepository {
  final _localDataSource = AttendanceLocalDataSource();
  final _remoteApi = GoogleSheetsApi();

  Future<bool> saveAttendance(AttendanceRecord record) async {
    await _localDataSource.saveToCSV(record);
    return await _remoteApi.syncRecord(record);
  }
}