import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'database_helper.dart';
import 'attendance_record.dart';
import 'course_repository.dart';
import 'timetable_repository.dart';
import 'student_repository.dart';

/// Repository for handling the check-in process.
class CheckInRepository {
  final dbHelper = DatabaseHelper.instance;
  final _supabase = Supabase.instance.client;

  /// Inserts a new attendance record into the database.
  ///
  /// Synchronizes with Supabase when online, and caches the result locally.
  Future<void> createAttendanceRecord(AttendanceRecord record) async {
    final db = await dbHelper.database;

    // 1. Try syncing to Supabase if online
    AttendanceRecord? supabaseRecord;
    try {
      final map = record.toMap();
      if (record.id == null) {
        map.remove('id');
      }

      final response = await _supabase
          .from('attendance_records')
          .insert(map)
          .select()
          .single();
      
      supabaseRecord = AttendanceRecord.fromMap(response);
      print('✅ Synced AttendanceRecord to Supabase: ID=${supabaseRecord.id}');
    } catch (e) {
      print('⚠️ Supabase AttendanceRecord insert error: $e');
    }

    // 2. Save locally (using Supabase-generated ID if available)
    final localRecord = supabaseRecord ?? record;
    await db.insert(
      'attendance_records',
      localRecord.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Checks if a student has already checked in for a specific slot today.
  ///
  /// Returns `true` if a record exists for the student and slot on the current date.
  Future<bool> hasCheckedInToday(int studentId, int timetableSlotId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Try Supabase first
    try {
      final response = await _supabase
          .from('attendance_records')
          .select()
          .eq('student_id', studentId)
          .eq('timetable_slot_id', timetableSlotId)
          .gte('timestamp', startOfDay.toIso8601String())
          .lt('timestamp', endOfDay.toIso8601String());
      
      if (response.isNotEmpty) {
        // Cache locally as a best-effort
        final db = await dbHelper.database;
        final record = AttendanceRecord.fromMap(response.first as Map<String, dynamic>);
        await db.insert(
          'attendance_records',
          record.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return true;
      }
    } catch (e) {
      print('⚠️ Supabase check if checked in today error: $e');
    }

    // Fallback to SQLite
    final db = await dbHelper.database;
    final result = await db.query(
      'attendance_records',
      where:
          'student_id = ? AND timetable_slot_id = ? AND timestamp >= ? AND timestamp < ?',
      whereArgs: [
        studentId,
        timetableSlotId,
        startOfDay.toIso8601String(),
        endOfDay.toIso8601String()
      ],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  /// Fetches all attendance records for a specific slot on a given date.
  Future<List<AttendanceRecord>> getRecordsForSlotOnDate(
      int timetableSlotId, DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Try Supabase first
    try {
      final List<dynamic> response = await _supabase
          .from('attendance_records')
          .select()
          .eq('timetable_slot_id', timetableSlotId)
          .gte('timestamp', startOfDay.toIso8601String())
          .lt('timestamp', endOfDay.toIso8601String());
      
      final records = response.map((item) => AttendanceRecord.fromMap(item as Map<String, dynamic>)).toList();

      // Cache locally
      final db = await dbHelper.database;
      final batch = db.batch();
      for (var record in records) {
        batch.insert('attendance_records', record.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);

      return records;
    } catch (e) {
      print('⚠️ Supabase fetch records for slot error: $e');
    }

    // Fallback to SQLite
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance_records',
      where: 'timetable_slot_id = ? AND timestamp >= ? AND timestamp < ?',
      whereArgs: [
        timetableSlotId,
        startOfDay.toIso8601String(),
        endOfDay.toIso8601String()
      ],
    );

    return List.generate(maps.length, (i) => AttendanceRecord.fromMap(maps[i]));
  }

  /// Creates "ABSENT" records for a list of students in a single batch.
  Future<void> batchCreateAbsentRecords(
      List<int> studentIds, int timetableSlotId, DateTime timestamp) async {
    final db = await dbHelper.database;

    // 1. Try syncing to Supabase if online
    List<AttendanceRecord> syncedRecords = [];
    try {
      final List<Map<String, dynamic>> mapsToInsert = studentIds.map((studentId) {
        final absentRecord = AttendanceRecord(
          studentId: studentId,
          timetableSlotId: timetableSlotId,
          type: 'AUTO',
          timestamp: timestamp,
          status: 'ABSENT',
          location: 'N/A',
          altitude: 0,
          latitude: 0,
          longitude: 0,
        );
        final map = absentRecord.toMap();
        map.remove('id');
        return map;
      }).toList();

      final List<dynamic> response = await _supabase
          .from('attendance_records')
          .insert(mapsToInsert)
          .select();
      
      syncedRecords = response.map((item) => AttendanceRecord.fromMap(item as Map<String, dynamic>)).toList();
      print('✅ Synced batch ABSENT records to Supabase');
    } catch (e) {
      print('⚠️ Supabase batch create absent records error: $e');
    }

    // 2. Save locally
    final batch = db.batch();
    if (syncedRecords.isNotEmpty) {
      for (final record in syncedRecords) {
        batch.insert('attendance_records', record.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } else {
      for (final studentId in studentIds) {
        final absentRecord = AttendanceRecord(
          studentId: studentId,
          timetableSlotId: timetableSlotId,
          type: 'AUTO',
          timestamp: timestamp,
          status: 'ABSENT',
          location: 'N/A',
          altitude: 0,
          latitude: 0,
          longitude: 0,
        );
        batch.insert('attendance_records', absentRecord.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
    await batch.commit(noResult: true);
  }

  /// Updates or inserts an attendance record for a student.
  Future<void> upsertAttendanceStatus(
      int studentId, int timetableSlotId, String newStatus) async {
    final db = await dbHelper.database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Try finding existing record on Supabase/SQLite
    final existing = await db.query(
      'attendance_records',
      where:
          'student_id = ? AND timetable_slot_id = ? AND timestamp >= ? AND timestamp < ?',
      whereArgs: [
        studentId,
        timetableSlotId,
        startOfDay.toIso8601String(),
        endOfDay.toIso8601String()
      ],
      limit: 1,
    );

    int? existingId;
    if (existing.isNotEmpty) {
      existingId = existing.first['id'] as int?;
    } else {
      // Check Supabase
      try {
        final response = await _supabase
            .from('attendance_records')
            .select()
            .eq('student_id', studentId)
            .eq('timetable_slot_id', timetableSlotId)
            .gte('timestamp', startOfDay.toIso8601String())
            .lt('timestamp', endOfDay.toIso8601String())
            .maybeSingle();
        if (response != null) {
          existingId = response['id'] as int?;
        }
      } catch (e) {
        print('⚠️ Supabase check existing status error: $e');
      }
    }

    if (existingId != null) {
      // Update
      final updatedMap = {
        'status': newStatus,
        'type': 'MANUAL_OVERRIDE',
      };
      
      try {
        await _supabase
            .from('attendance_records')
            .update(updatedMap)
            .eq('id', existingId);
        print('✅ Updated attendance status on Supabase');
      } catch (e) {
        print('⚠️ Supabase update attendance status error: $e');
      }

      await db.update('attendance_records',
          {'status': newStatus, 'type': 'MANUAL_OVERRIDE'},
          where: 'id = ?', whereArgs: [existingId]);
    } else {
      // Create new
      final newRecord = AttendanceRecord(
          studentId: studentId,
          timetableSlotId: timetableSlotId,
          type: 'MANUAL_CREATE',
          timestamp: now,
          status: newStatus,
          location: 'MANUAL',
          altitude: 0,
          latitude: 0,
          longitude: 0);
      await createAttendanceRecord(newRecord);
    }
  }

  /// Automatically marks students as ABSENT if they missed class sessions that have already completed.
  Future<void> backfillAbsentRecords(int courseId) async {
    try {
      final db = await dbHelper.database;
      
      // 1. Get the course
      final course = await CourseRepository().getCourseById(courseId);
      if (course == null) return;
      
      // 2. Get all timetable slots for the course
      final slots = await TimetableRepository().getTimetableForCourse(courseId);
      if (slots.isEmpty) return;
      
      // 3. Get all students for the course
      final students = await StudentRepository().getStudentsForCourse(courseId);
      if (students.isEmpty) return;
      
      final now = DateTime.now();
      
      // Let's normalize startDate to start of day
      DateTime startDate = DateTime(course.startDate.year, course.startDate.month, course.startDate.day);
      DateTime endDate = DateTime(now.year, now.month, now.day);
      
      // Limit lookback to last 30 days to avoid huge loops or operations on misconfigured dates
      final thirtyDaysAgo = endDate.subtract(const Duration(days: 30));
      if (startDate.isBefore(thirtyDaysAgo)) {
        startDate = thirtyDaysAgo;
      }
      
      // 4. Gather all existing records for the course's slots to avoid querying inside the loops
      final slotIds = slots.map((s) => s.id!).toList();
      if (slotIds.isEmpty) return;
      
      final String placeholders = slotIds.map((_) => '?').join(', ');
      final String query = '''
        SELECT student_id, timetable_slot_id, timestamp 
        FROM attendance_records 
        WHERE timetable_slot_id IN ($placeholders)
      ''';
      
      final List<Map<String, dynamic>> existingRows = await db.rawQuery(query, slotIds);
      
      final Set<String> existingRecordsSet = {};
      for (final row in existingRows) {
        final studentId = row['student_id'] as int;
        final slotId = row['timetable_slot_id'] as int;
        final timestampStr = row['timestamp'] as String;
        final timestamp = DateTime.parse(timestampStr);
        final dateKey = "${timestamp.year}-${timestamp.month}-${timestamp.day}";
        existingRecordsSet.add("${studentId}_${slotId}_$dateKey");
      }
      
      final List<AttendanceRecord> newAbsentRecords = [];
      
      // Loop through each day from startDate to endDate (inclusive)
      for (int i = 0; i <= endDate.difference(startDate).inDays; i++) {
        final checkDate = startDate.add(Duration(days: i));
        final weekday = checkDate.weekday;
        
        final daySlots = slots.where((s) => s.dayOfWeek == weekday).toList();
        for (final slot in daySlots) {
          final timeParts = slot.endTime.split(':');
          final endHour = int.parse(timeParts[0]);
          final endMinute = int.parse(timeParts[1]);
          
          final slotEndDateTime = DateTime(checkDate.year, checkDate.month, checkDate.day, endHour, endMinute);
          
          // If the slot has already ended (plus 10 mins buffer for late/grace check-in)
          if (now.isAfter(slotEndDateTime.add(const Duration(minutes: 10)))) {
            final dateKey = "${checkDate.year}-${checkDate.month}-${checkDate.day}";
            
            for (final student in students) {
              final lookupKey = "${student.id}_${slot.id}_$dateKey";
              if (!existingRecordsSet.contains(lookupKey)) {
                newAbsentRecords.add(
                  AttendanceRecord(
                    studentId: student.id!,
                    timetableSlotId: slot.id!,
                    type: 'AUTO',
                    timestamp: slotEndDateTime,
                    status: 'ABSENT',
                    location: 'N/A',
                    altitude: 0,
                    latitude: 0,
                    longitude: 0,
                  ),
                );
              }
            }
          }
        }
      }
      
      if (newAbsentRecords.isNotEmpty) {
        print("Backfilling ${newAbsentRecords.length} ABSENT records...");
        
        try {
          final List<Map<String, dynamic>> mapsToInsert = newAbsentRecords.map((record) {
            final map = record.toMap();
            map.remove('id');
            return map;
          }).toList();
          
          final List<dynamic> response = await _supabase
              .from('attendance_records')
              .insert(mapsToInsert)
              .select();
              
          final synced = response.map((item) => AttendanceRecord.fromMap(item as Map<String, dynamic>)).toList();
          final batch = db.batch();
          for (final record in synced) {
            batch.insert('attendance_records', record.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await batch.commit(noResult: true);
          print("✅ Synced and saved backfilled ABSENT records");
        } catch (e) {
          print("⚠️ Supabase backfill insert error, saving locally only: $e");
          final batch = db.batch();
          for (final record in newAbsentRecords) {
            batch.insert('attendance_records', record.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
          }
          await batch.commit(noResult: true);
        }
      }
    } catch (e, stack) {
      print("Error in backfillAbsentRecords: $e\n$stack");
    }
  }
}
