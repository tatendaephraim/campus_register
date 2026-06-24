import 'database_helper.dart';
import 'timetable.dart';

/// A service to determine the currently active class for a student.
class CheckInService {
  final dbHelper = DatabaseHelper.instance;

  /// Finds the currently active timetable slot for a given course.
  ///
  /// Checks the current day and time against the course's schedule.
  /// Returns the [TimetableSlot] if a class is active, otherwise returns `null`.
  Future<TimetableSlot?> getActiveSlot(int courseId) async {
    final db = await dbHelper.database;
    final now = DateTime.now();
    final dayOfWeek = now.weekday; // Monday = 1, Sunday = 7

    // Format current time as "HH:MM" for comparison
    final currentTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final List<Map<String, dynamic>> maps = await db.query(
      'timetable_slots',
      where:
          'course_id = ? AND day_of_week = ? AND ? BETWEEN start_time AND end_time',
      whereArgs: [courseId, dayOfWeek, currentTime],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return TimetableSlot.fromMap(maps.first);
    }
    return null;
  }
}
