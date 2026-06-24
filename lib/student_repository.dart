import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'database_helper.dart';
import 'student.dart';

/// Repository for handling data operations for the [Student] model.
class StudentRepository {
  final dbHelper = DatabaseHelper.instance;
  final _supabase = Supabase.instance.client;

  /// Fetches all students for a specific course.
  Future<List<Student>> getStudentsForCourse(int courseId) async {
    // Try Supabase first
    try {
      final List<dynamic> response = await _supabase
          .from('students')
          .select()
          .eq('course_id', courseId)
          .order('name');
      
      final students = response.map((item) => Student.fromMap(item as Map<String, dynamic>)).toList();

      // Cache all locally
      final db = await dbHelper.database;
      final batch = db.batch();
      for (var student in students) {
        batch.insert('students', student.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);

      return students;
    } catch (e) {
      print('⚠️ Supabase fetch students for course error: $e');
    }

    // Fallback to SQLite
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: 'course_id = ?',
      whereArgs: [courseId],
      orderBy: 'name',
    );
    return List.generate(maps.length, (i) => Student.fromMap(maps[i]));
  }

  /// Adds a new student to a course with a unique registration code.
  Future<Student> addStudent(String name, int courseId) async {
    final db = await dbHelper.database;
    final registrationCode = (100000 + Random().nextInt(900000)).toString();

    final student = Student(
      courseId: courseId,
      name: name,
      deviceAppId: registrationCode,
    );

    // 1. Try syncing to Supabase if online
    Student? supabaseStudent;
    try {
      final map = student.toMap();
      if (student.id == null) {
        map.remove('id');
      }

      final response = await _supabase
          .from('students')
          .insert(map)
          .select()
          .single();
      
      supabaseStudent = Student.fromMap(response);
      print('✅ Synced Student to Supabase: ${supabaseStudent.name}');
    } catch (e) {
      print('⚠️ Supabase Student add error: $e');
    }

    // 2. Save locally
    final localStudent = supabaseStudent ?? student;
    final id = await db.insert(
      'students',
      localStudent.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (localStudent.id != null) {
      return localStudent;
    } else {
      return Student.fromMap(localStudent.toMap()..['id'] = id);
    }
  }

  /// Registers a device for a student using a registration code.
  Future<Student?> registerDevice(
      String registrationCode, String newDeviceAppId) async {
    final db = await dbHelper.database;

    // 1. Try resolving and updating on Supabase first if online
    Student? supabaseUpdatedStudent;
    try {
      final List<dynamic> response = await _supabase
          .from('students')
          .select()
          .eq('device_app_id', registrationCode);
      
      if (response.isNotEmpty) {
        final studentMap = response.first as Map<String, dynamic>;
        final student = Student.fromMap(studentMap);
        
        final updatedMap = {
          'id': student.id,
          'course_id': student.courseId,
          'name': student.name,
          'device_app_id': newDeviceAppId,
        };

        final updateResponse = await _supabase
            .from('students')
            .update(updatedMap)
            .eq('id', student.id!)
            .select()
            .single();
        
        supabaseUpdatedStudent = Student.fromMap(updateResponse);
        print('✅ Registered device on Supabase for student: ${supabaseUpdatedStudent.name}');
      }
    } catch (e) {
      print('⚠️ Supabase registerDevice error: $e');
    }

    // 2. Save/Update locally
    // Look up student locally
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: 'device_app_id = ?',
      whereArgs: [registrationCode],
    );

    if (maps.isNotEmpty) {
      final student = Student.fromMap(maps.first);
      final updatedStudent = supabaseUpdatedStudent ?? Student(
        id: student.id,
        courseId: student.courseId,
        name: student.name,
        deviceAppId: newDeviceAppId,
      );

      await db.update(
        'students',
        updatedStudent.toMap(),
        where: 'id = ?',
        whereArgs: [student.id],
      );
      return updatedStudent;
    } else if (supabaseUpdatedStudent != null) {
      // If found in Supabase but not locally, cache it locally
      await db.insert(
        'students',
        supabaseUpdatedStudent.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return supabaseUpdatedStudent;
    }

    return null;
  }

  /// Fetches a student by their permanent device ID.
  Future<Student?> getStudentByDeviceId(String deviceId) async {
    // Try Supabase first
    try {
      final response = await _supabase
          .from('students')
          .select()
          .eq('device_app_id', deviceId)
          .maybeSingle();
      
      if (response != null) {
        final student = Student.fromMap(response);
        // Cache locally
        final db = await dbHelper.database;
        await db.insert(
          'students',
          student.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return student;
      }
    } catch (e) {
      print('⚠️ Supabase fetch student by deviceId error: $e');
    }

    // Fallback to SQLite
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: 'device_app_id = ?',
      whereArgs: [deviceId],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return Student.fromMap(maps.first);
    }
    return null;
  }

  /// Fetches all students in the database.
  Future<List<Student>> getAllStudents() async {
    // Try Supabase first
    try {
      final List<dynamic> response = await _supabase
          .from('students')
          .select()
          .order('name');
      
      final students = response.map((item) => Student.fromMap(item as Map<String, dynamic>)).toList();

      // Cache all locally
      final db = await dbHelper.database;
      final batch = db.batch();
      for (var student in students) {
        batch.insert('students', student.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);

      return students;
    } catch (e) {
      print('⚠️ Supabase fetch all students error: $e');
    }

    // Fallback to SQLite
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('students', orderBy: 'name');
    return List.generate(maps.length, (i) => Student.fromMap(maps[i]));
  }
}
