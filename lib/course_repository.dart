import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'database_helper.dart';
import 'course.dart';

/// Repository for handling data operations for the [Course] model.
class CourseRepository {
  final dbHelper = DatabaseHelper.instance;
  final _supabase = Supabase.instance.client;

  /// Inserts a new course into the database.
  ///
  /// Synchronizes with Supabase when online, and caches the result locally.
  Future<Course> createCourse(Course course) async {
    final db = await dbHelper.database;

    // 1. Try syncing to Supabase if online
    Course? supabaseCourse;
    try {
      final map = course.toMap();
      if (course.id == null) {
        map.remove('id');
      }
      
      final response = await _supabase
          .from('courses')
          .insert(map)
          .select()
          .single();
      
      supabaseCourse = Course.fromMap(response);
      print('✅ Synced Course to Supabase: ${supabaseCourse.name}');
    } catch (e) {
      print('⚠️ Supabase Course insert error: $e');
    }

    // 2. Save locally (using Supabase-generated ID if available)
    final localCourse = supabaseCourse ?? course;
    final id = await db.insert(
      'courses',
      localCourse.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (localCourse.id != null) {
      return localCourse;
    } else {
      return Course.fromMap(localCourse.toMap()..['id'] = id);
    }
  }

  /// Updates an existing course in the database.
  Future<void> updateCourse(Course course) async {
    final db = await dbHelper.database;

    // 1. Try updating in Supabase
    try {
      await _supabase
          .from('courses')
          .update(course.toMap())
          .eq('id', course.id!);
      print('✅ Updated Course on Supabase: ${course.name}');
    } catch (e) {
      print('⚠️ Supabase Course update error: $e');
    }

    // 2. Update locally
    await db.update(
      'courses',
      course.toMap(),
      where: 'id = ?',
      whereArgs: [course.id],
    );
  }

  /// Fetches a single course by its ID.
  Future<Course?> getCourseById(int courseId) async {
    // Try Supabase first
    try {
      final response = await _supabase
          .from('courses')
          .select()
          .eq('id', courseId)
          .maybeSingle();
      
      if (response != null) {
        final course = Course.fromMap(response);
        // Cache locally
        final db = await dbHelper.database;
        await db.insert(
          'courses',
          course.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return course;
      }
    } catch (e) {
      print('⚠️ Supabase fetch course error: $e');
    }

    // Fallback to SQLite
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'courses',
      where: 'id = ?',
      whereArgs: [courseId],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return Course.fromMap(maps.first);
    }
    return null;
  }

  /// Fetches all courses for a specific teacher.
  Future<List<Course>> getCoursesForTeacher(int teacherId) async {
    // Try Supabase first
    try {
      final List<dynamic> response = await _supabase
          .from('courses')
          .select()
          .eq('teacher_id', teacherId)
          .order('name');
      
      final courses = response.map((item) => Course.fromMap(item as Map<String, dynamic>)).toList();

      // Cache all locally
      final db = await dbHelper.database;
      final batch = db.batch();
      for (var course in courses) {
        batch.insert('courses', course.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);

      return courses;
    } catch (e) {
      print('⚠️ Supabase fetch courses error: $e');
    }

    // Fallback to SQLite
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'courses',
      where: 'teacher_id = ?',
      whereArgs: [teacherId],
      orderBy: 'name',
    );
    return List.generate(maps.length, (i) => Course.fromMap(maps[i]));
  }

  /// Fetches all registered courses.
  Future<List<Course>> getAllCourses() async {
    // Try Supabase first
    try {
      final List<dynamic> response = await _supabase
          .from('courses')
          .select();
      
      final courses = response.map((item) => Course.fromMap(item as Map<String, dynamic>)).toList();

      // Cache all locally
      final db = await dbHelper.database;
      final batch = db.batch();
      for (var course in courses) {
        batch.insert('courses', course.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);

      return courses;
    } catch (e) {
      print('⚠️ Supabase fetch all courses error: $e');
    }

    // Fallback to SQLite
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('courses');
    return List.generate(maps.length, (i) => Course.fromMap(maps[i]));
  }
}
