import 'models/attendance_event.dart';

/// RFC 4180 CSV of the log.
String eventsToCsv(List<AttendanceEvent> events) {
  final rows = [
    [...AttendanceEvent.fieldNames, 'hash'],
    for (final e in events) [...e.values, e.hash],
  ];
  return rows.map((r) => '${r.map(_cell).join(',')}\r\n').join();
}

String _cell(String value) {
  // Text a student typed must not run as a formula in a spreadsheet.
  final safe = RegExp(r'^[=+\-@\t\r]').hasMatch(value) ? "'$value" : value;
  if (!RegExp('[",\r\n]').hasMatch(safe)) return safe;
  return '"${safe.replaceAll('"', '""')}"';
}
