import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'database_helper.dart';
import 'timetable.dart';

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
      print('⚠️ Supabase fetch timetable slots error: $e');
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
      print('✅ Synced TimetableSlot to Supabase: ID=${supabaseSlot.id}');
    } catch (e) {
      print('⚠️ Supabase TimetableSlot insert error: $e');
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
      print('✅ Deleted TimetableSlot from Supabase: ID=$slotId');
    } catch (e) {
      print('⚠️ Supabase TimetableSlot delete error: $e');
    }

    // 2. Delete locally
    await db.delete('timetable_slots', where: 'id = ?', whereArgs: [slotId]);
  }
}
