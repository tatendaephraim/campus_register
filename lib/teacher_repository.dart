import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'database_helper.dart';
import 'teacher.dart';

/// Repository for handling data operations for the [Teacher] model.
class TeacherRepository {
  final dbHelper = DatabaseHelper.instance;
  final _supabase = Supabase.instance.client;

  /// Inserts a new teacher if they don't exist, or retrieves the existing
  /// teacher record if they do.
  ///
  /// Synchronizes with Supabase when online, and caches the result locally.
  Future<Teacher> upsertTeacher(Teacher teacher) async {
    final db = await dbHelper.database;

    // 1. Try syncing to Supabase if online
    Teacher? supabaseTeacher;
    try {
      final map = teacher.toMap();
      // Remove id if it is null so Supabase generates it
      if (teacher.id == null) {
        map.remove('id');
      }
      
      final response = await _supabase
          .from('teachers')
          .upsert(map, onConflict: 'email')
          .select()
          .single();
      
      supabaseTeacher = Teacher.fromMap(response);
      print('✅ Synced Teacher to Supabase: ${supabaseTeacher.name}');
    } catch (e) {
      print('⚠️ Supabase Teacher upsert error: $e');
    }

    // 2. Save locally (using Supabase-generated ID if available)
    final localTeacher = supabaseTeacher ?? teacher;
    if (localTeacher.id != null) {
      await db.insert(
        'teachers',
        localTeacher.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return localTeacher;
    } else {
      final id = await db.insert(
        'teachers',
        localTeacher.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      if (id != 0) {
        return Teacher.fromMap(localTeacher.toMap()..['id'] = id);
      } else {
        return getTeacherByEmail(localTeacher.email);
      }
    }
  }

  /// Fetches a single teacher from the database by their email.
  Future<Teacher> getTeacherByEmail(String email) async {
    // Try Supabase first
    try {
      final response = await _supabase
          .from('teachers')
          .select()
          .eq('email', email)
          .maybeSingle();
      
      if (response != null) {
        final teacher = Teacher.fromMap(response);
        // Cache locally
        final db = await dbHelper.database;
        await db.insert(
          'teachers',
          teacher.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return teacher;
      }
    } catch (e) {
      print('⚠️ Supabase fetch teacher error: $e');
    }

    // Fallback to SQLite
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'teachers',
      where: 'email = ?',
      whereArgs: [email],
    );

    return Teacher.fromMap(maps.first);
  }

  /// Fetches all teachers in the database.
  Future<List<Teacher>> getAllTeachers() async {
    // Try Supabase first
    try {
      final List<dynamic> response = await _supabase
          .from('teachers')
          .select()
          .order('name');
      
      final teachers = response.map((item) => Teacher.fromMap(item as Map<String, dynamic>)).toList();

      // Cache all locally
      final db = await dbHelper.database;
      final batch = db.batch();
      for (var teacher in teachers) {
        batch.insert('teachers', teacher.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);

      return teachers;
    } catch (e) {
      print('⚠️ Supabase fetch all teachers error: $e');
    }

    // Fallback to SQLite
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('teachers', orderBy: 'name');
    return List.generate(maps.length, (i) => Teacher.fromMap(maps[i]));
  }
}
