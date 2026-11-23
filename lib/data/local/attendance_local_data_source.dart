import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/attendance_record.dart';

class AttendanceLocalDataSource {
  Future<void> saveToCSV(AttendanceRecord record) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/attendance_log.csv');

    final exists = await file.exists();
    if (!exists) {
      await file.writeAsString('Name,Type,Timestamp,Location\n');
    }

    final line = '${record.name},${record.type},${record.timestamp},${record.location}\n';
    await file.writeAsString(line, mode: FileMode.append);
  }
}