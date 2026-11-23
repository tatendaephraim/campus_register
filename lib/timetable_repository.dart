import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'database_helper.dart';
import 'timetable.dart';
import 'course_repository.dart';

/// Repository for handling data operations for the [TimetableSlot] model.
class TimetableRepository {
  final dbHelper = DatabaseHelper.instance;
  final _supabase = Supabase.instance.client;

  /// Fetches all timetable slots for a specific course.
  ///
  /// Synchronizes with Supabase when online, and caches the result locally.
  Future<List<TimetableSlot>> getTimetableForCourse(int courseId) async {
    // Try Supabase first
    try {
      final List<dynamic> response = await _supabase
          .from('timetable_slots')
          .select()
          .eq('course_id', courseId)
          .order('day_of_week')
          .order('start_time');
      
      final slots = response.map((item) => TimetableSlot.fromMap(item as Map<String, dynamic>)).toList();

      // Cache all locally
      final db = await dbHelper.database;
      final batch = db.batch();
      for (var slot in slots) {
        batch.insert('timetable_slots', slot.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);

      return slots;
    } catch (e) {
      debugPrint('⚠️ Supabase fetch timetable slots error: $e');
    }

    // Fallback to SQLite
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'timetable_slots',
      where: 'course_id = ?',
      whereArgs: [courseId],
      orderBy: 'day_of_week, start_time',
    );

    return List.generate(maps.length, (i) {
      return TimetableSlot.fromMap(maps[i]);
    });
  }

  /// Inserts a new timetable slot into the database.
  Future<TimetableSlot> addTimetableSlot(TimetableSlot slot) async {
    final db = await dbHelper.database;

    // 1. Try syncing to Supabase if online
    TimetableSlot? supabaseSlot;
    try {
      final map = slot.toMap();
      if (slot.id == null) {
        map.remove('id');
      }

      final response = await _supabase
          .from('timetable_slots')
          .insert(map)
          .select()
          .single();
      
      supabaseSlot = TimetableSlot.fromMap(response);
      debugPrint('✅ Synced TimetableSlot to Supabase: ID=${supabaseSlot.id}');
    } catch (e) {
      debugPrint('⚠️ Supabase TimetableSlot insert error: $e');
    }

    // 2. Save locally (using Supabase-generated ID if available)
    final localSlot = supabaseSlot ?? slot;
    final id = await db.insert(
      'timetable_slots',
      localSlot.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (localSlot.id != null) {
      return localSlot;
    } else {
      return TimetableSlot.fromMap(localSlot.toMap()..['id'] = id);
    }
  }

  /// Deletes a timetable slot from the database.
  Future<void> deleteTimetableSlot(int slotId) async {
    final db = await dbHelper.database;

    // 1. Try deleting from Supabase
    try {
      await _supabase
          .from('timetable_slots')
          .delete()
          .eq('id', slotId);
      debugPrint('✅ Deleted TimetableSlot from Supabase: ID=$slotId');
    } catch (e) {
      debugPrint('⚠️ Supabase TimetableSlot delete error: $e');
    }

    // 2. Delete locally
    await db.delete('timetable_slots', where: 'id = ?', whereArgs: [slotId]);
  }

  /// Checks if a proposed timetable slot for a venue clashes with any existing slots.
  /// Returns a map with 'clash': true/false, and 'message': String details of the clash.
  Future<Map<String, dynamic>> checkClash(
    int venueId,
    int dayOfWeek,
    String startTime,
    String endTime, {
    int? excludeCourseId,
  }) async {
    final courseRepo = CourseRepository();
    final allCourses = await courseRepo.getAllCourses();

    // Filter courses assigned to this venue (excluding the current course if specified)
    final venueCourses = allCourses.where((c) => c.venueId == venueId && c.id != excludeCourseId).toList();

    for (final course in venueCourses) {
      final slots = await getTimetableForCourse(course.id!);
      for (final slot in slots) {
        if (slot.dayOfWeek == dayOfWeek) {
          // Check overlap: startA < endB && endA > startB
          if (startTime.compareTo(slot.endTime) < 0 && endTime.compareTo(slot.startTime) > 0) {
            return {
              'clash': true,
              'course': course,
              'slot': slot,
              'message': 'This time clashes with course "${course.name}" (${_getDayName(slot.dayOfWeek)} ${slot.startTime}–${slot.endTime}) scheduled in the same venue.',
            };
          }
        }
      }
    }

    return {'clash': false};
  }

  String _getDayName(int day) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    if (day >= 1 && day <= 7) return days[day - 1];
    return 'Unknown';
  }
}
