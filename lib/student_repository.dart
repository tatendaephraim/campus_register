import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'database_helper.dart';
import 'student.dart';

/// Repository for handling data operations for the [Student] model.
class StudentRepository {
  final dbHelper = DatabaseHelper.instance;
  final _supabase = Supabase.instance.client;

  /// Fetches all students enrolled in a specific course.
  Future<List<Student>> getStudentsForCourse(int courseId) async {
    // Try Supabase first
    try {
      final response = await _supabase
          .from('course_students')
          .select('students!inner(*)')
          .eq('course_id', courseId);
      
      final students = response.map((item) => Student.fromMap(item['students'] as Map<String, dynamic>)).toList();

      // Cache all locally
      final db = await dbHelper.database;
      final batch = db.batch();
      for (var student in students) {
        batch.insert('students', student.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        batch.insert('course_students', {'course_id': courseId, 'student_id': student.id}, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);

      return students;
    } catch (e) {
      print('⚠️ Supabase fetch students for course error: $e');
    }

    // Fallback to SQLite using JOIN
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT s.* FROM students s
      INNER JOIN course_students cs ON s.id = cs.student_id
      WHERE cs.course_id = ?
      ORDER BY s.name
      ''',
      [courseId],
    );
    return List.generate(maps.length, (i) => Student.fromMap(maps[i]));
  }

  /// Adds a new student to a course with a unique registration code.
  Future<Student> addStudent(String name, int courseId) async {
    final db = await dbHelper.database;
    final registrationCode = (100000 + Random().nextInt(900000)).toString();

    // Find the organization from the course's teacher
    int? organizationId;
    try {
      final List<Map<String, dynamic>> courseMaps = await db.query(
        'courses',
        where: 'id = ?',
        whereArgs: [courseId],
      );
      if (courseMaps.isNotEmpty) {
        final teacherId = courseMaps.first['teacher_id'] as int;
        final List<Map<String, dynamic>> teacherMaps = await db.query(
          'teachers',
          where: 'id = ?',
          whereArgs: [teacherId],
        );
        if (teacherMaps.isNotEmpty) {
          organizationId = teacherMaps.first['organization_id'] as int?;
        }
      }
    } catch (_) {}

    final student = Student(
      courseId: courseId,
      organizationId: organizationId,
      name: name,
      deviceAppId: registrationCode,
      isApproved: 1, // Auto-approve demo/legacy students
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
    } on PostgrestException catch (e) {
      print('⚠️ Supabase Student add error: $e');
      rethrow;
    } catch (e) {
      print('⚠️ Supabase Student add connection/offline error: $e');
    }

    // 2. Save locally
    final localStudent = supabaseStudent ?? student;
    final id = await db.insert(
      'students',
      localStudent.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final finalStudent = localStudent.id != null
        ? localStudent
        : Student.fromMap(localStudent.toMap()..['id'] = id);

    // Link to course in course_students junction table
    await enrollStudentInCourse(finalStudent.id!, courseId);

    return finalStudent;
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
          .eq('device_app_id', registrationCode)
          .timeout(const Duration(seconds: 8));
      
      if (response.isNotEmpty) {
        final studentMap = response.first as Map<String, dynamic>;
        final student = Student.fromMap(studentMap);
        
        final updatedMap = {
          'id': student.id,
          'name': student.name,
          'device_app_id': newDeviceAppId,
        };

        final updateResponse = await _supabase
            .from('students')
            .update(updatedMap)
            .eq('id', student.id!)
            .select()
            .single()
            .timeout(const Duration(seconds: 8));
        
        supabaseUpdatedStudent = Student.fromMap(updateResponse);
        print('✅ Registered device on Supabase for student: ${supabaseUpdatedStudent.name}');
      }
    } catch (e) {
      print('⚠️ Supabase registerDevice error: $e');
    }

    // 2. Save/Update locally
    try {
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

        if (supabaseUpdatedStudent != null) {
          await db.delete(
            'students',
            where: 'id = ?',
            whereArgs: [student.id],
          );

          final map = supabaseUpdatedStudent.toMap();

          await db.insert(
            'students',
            map,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } else {
          await db.update(
            'students',
            updatedStudent.toMap(),
            where: 'id = ?',
            whereArgs: [student.id],
          );
        }
        
        final List<Map<String, dynamic>> refreshed = await db.query(
          'students',
          where: 'id = ?',
          whereArgs: [student.id],
        );
        return refreshed.isNotEmpty ? Student.fromMap(refreshed.first) : updatedStudent;
      } else if (supabaseUpdatedStudent != null) {
        // If found in Supabase but not locally, cache it locally
        await db.insert(
          'students',
          supabaseUpdatedStudent.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return supabaseUpdatedStudent;
      }
    } catch (e) {
      print('⚠️ Local database registerDevice error: $e');
    }
    return null;
  }

  /// Fetches all students associated with a permanent device ID (multiple courses support).
  Future<List<Student>> getStudentsByDeviceId(String deviceId) async {
    try {
      final List<dynamic> response = await _supabase
          .from('students')
          .select()
          .eq('device_app_id', deviceId)
          .timeout(const Duration(seconds: 8));

      final students = response.map((item) => Student.fromMap(item as Map<String, dynamic>)).toList();

      final db = await dbHelper.database;
      final batch = db.batch();
      for (var student in students) {
        final map = student.toMap();
        batch.insert('students', map, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    } catch (e) {
      print('⚠️ Supabase getStudentsByDeviceId error: $e');
    }

    // Fallback to SQLite
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'students',
        where: 'device_app_id = ?',
        whereArgs: [deviceId],
      );
      return List.generate(maps.length, (i) => Student.fromMap(maps[i]));
    } catch (e) {
      print('⚠️ SQLite getStudentsByDeviceId error: $e');
    }
    return [];
  }

  /// Fetches a student by their permanent device ID.
  Future<Student?> getStudentByDeviceId(String deviceId) async {
    // Try Supabase first
    try {
      final List<dynamic> response = await _supabase
          .from('students')
          .select()
          .eq('device_app_id', deviceId)
          .limit(1)
          .timeout(const Duration(seconds: 8));
      
      if (response.isNotEmpty) {
        final student = Student.fromMap(response.first);
        // Cache locally
        final db = await dbHelper.database;
        final map = student.toMap();
        await db.insert(
          'students',
          map,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return Student.fromMap(map);
      }
    } catch (e) {
      print('⚠️ Supabase fetch student by deviceId error: $e');
    }

    // Fallback to SQLite
    try {
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
    } catch (e) {
      print('⚠️ SQLite getStudentByDeviceId error: $e');
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

  /// Updates a student's name in both Supabase and local SQLite database.
  Future<void> updateStudent(Student student) async {
    final db = await dbHelper.database;

    // 1. Try updating in Supabase
    try {
      await _supabase
          .from('students')
          .update({'name': student.name})
          .eq('id', student.id!);
      print('✅ Updated student in Supabase: ${student.name}');
    } catch (e) {
      print('⚠️ Supabase Student update error: $e');
    }

    // 2. Update locally
    await db.update(
      'students',
      student.toMap(),
      where: 'id = ?',
      whereArgs: [student.id],
    );
  }

  /// Deletes a student (and their attendance records) from Supabase and SQLite.
  Future<void> deleteStudent(int studentId) async {
    final db = await dbHelper.database;

    // 1. Try deleting in Supabase
    try {
      // First delete attendance records for this student
      await _supabase
          .from('attendance_records')
          .delete()
          .eq('student_id', studentId);
      
      // Then delete the student
      await _supabase
          .from('students')
          .delete()
          .eq('id', studentId);
      
      print('✅ Deleted student and attendance records in Supabase: ID=$studentId');
    } catch (e) {
      print('⚠️ Supabase Student delete error: $e');
    }

    // 2. Delete locally
    await db.transaction((txn) async {
      await txn.delete(
        'attendance_records',
        where: 'student_id = ?',
        whereArgs: [studentId],
      );
      await txn.delete(
        'students',
        where: 'id = ?',
        whereArgs: [studentId],
      );
    });
  }

  /// Unbinds a device ID from all student profiles, resetting their codes.
  Future<void> unbindDevice(String deviceId) async {
    final db = await dbHelper.database;

    // 1. In Supabase, reset the device_app_id for students matching this deviceId back to a random code
    try {
      final List<dynamic> response = await _supabase
          .from('students')
          .select()
          .eq('device_app_id', deviceId);
      
      for (var item in response) {
        final studentId = item['id'] as int;
        final resetCode = (100000 + Random().nextInt(900000)).toString();
        await _supabase
            .from('students')
            .update({'device_app_id': resetCode})
            .eq('id', studentId);
      }
      print('✅ Unbound device in Supabase for device: $deviceId');
    } catch (e) {
      print('⚠️ Supabase unbindDevice error: $e');
    }

    // 2. Locally, reset the device_app_id back to a random code
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'students',
        where: 'device_app_id = ?',
        whereArgs: [deviceId],
      );
      for (var map in maps) {
        final id = map['id'] as int;
        final resetCode = (100000 + Random().nextInt(900000)).toString();
        await db.update(
          'students',
          {'device_app_id': resetCode},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    } catch (e) {
      print('⚠️ Local database unbindDevice error: $e');
    }
  }

  /// Fetches pending students for an organization.
  Future<List<Student>> getPendingStudents(int organizationId) async {
    try {
      final List<dynamic> response = await _supabase
          .from('students')
          .select()
          .eq('organization_id', organizationId)
          .eq('is_approved', 0)
          .order('name');
      return response.map((item) => Student.fromMap(item as Map<String, dynamic>)).toList();
    } catch (e) {
      print('⚠️ Supabase fetch pending students error: $e');
    }

    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: 'organization_id = ? AND is_approved = 0',
      whereArgs: [organizationId],
      orderBy: 'name',
    );
    return List.generate(maps.length, (i) => Student.fromMap(maps[i]));
  }

  /// Fetches approved students for an organization.
  Future<List<Student>> getApprovedStudents(int organizationId) async {
    try {
      final List<dynamic> response = await _supabase
          .from('students')
          .select()
          .eq('organization_id', organizationId)
          .eq('is_approved', 1)
          .order('name');
      return response.map((item) => Student.fromMap(item as Map<String, dynamic>)).toList();
    } catch (e) {
      print('⚠️ Supabase fetch approved students error: $e');
    }

    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: 'organization_id = ? AND is_approved = 1',
      whereArgs: [organizationId],
      orderBy: 'name',
    );
    return List.generate(maps.length, (i) => Student.fromMap(maps[i]));
  }

  /// Approves a pending student.
  Future<void> approveStudent(int studentId) async {
    try {
      await _supabase
          .from('students')
          .update({'is_approved': 1})
          .eq('id', studentId);
      print('✅ Approved student $studentId on Supabase');
    } catch (e) {
      print('⚠️ Supabase approve student error: $e');
    }

    final db = await dbHelper.database;
    await db.update(
      'students',
      {'is_approved': 1},
      where: 'id = ?',
      whereArgs: [studentId],
    );
  }

  /// Suspends (blocks) a student by revoking approval.
  Future<void> suspendStudent(int studentId) async {
    try {
      await _supabase
          .from('students')
          .update({'is_approved': 0})
          .eq('id', studentId);
      print('✅ Suspended student $studentId on Supabase');
    } catch (e) {
      print('⚠️ Supabase suspendStudent error: $e');
    }

    final db = await dbHelper.database;
    await db.update(
      'students',
      {'is_approved': 0},
      where: 'id = ?',
      whereArgs: [studentId],
    );
  }

  /// Rejects (deletes) a pending student.
  Future<void> rejectStudent(int studentId) async {
    try {
      await _supabase.from('students').delete().eq('id', studentId);
      print('✅ Rejected and deleted student $studentId from Supabase');
    } catch (e) {
      print('⚠️ Supabase reject student error: $e');
    }

    final db = await dbHelper.database;
    await db.delete(
      'students',
      where: 'id = ?',
      whereArgs: [studentId],
    );
  }

  /// Enrolls a student in a course (inserts into course_students table).
  Future<void> enrollStudentInCourse(int studentId, int courseId) async {
    try {
      await _supabase
          .from('course_students')
          .insert({'course_id': courseId, 'student_id': studentId});
      print('✅ Enrolled student $studentId in course $courseId on Supabase');
    } catch (e) {
      print('⚠️ Supabase enroll student in course error: $e');
    }

    final db = await dbHelper.database;
    await db.insert(
      'course_students',
      {'course_id': courseId, 'student_id': studentId},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Adds a new student to an organization with a unique registration code.
  Future<Student> addStudentToOrganization(String name, String registrationCode, int organizationId, {String? email}) async {
    final db = await dbHelper.database;

    final student = Student(
      organizationId: organizationId,
      name: name,
      email: email,
      deviceAppId: registrationCode,
      isApproved: 0, // Pending admin approval
    );

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
    } on PostgrestException catch (e) {
      print('⚠️ Supabase Student add to organization error: $e');
      rethrow;
    } catch (e) {
      print('⚠️ Supabase Student add to organization connection/offline error: $e');
    }

    // 2. Save locally
    final localStudent = supabaseStudent ?? student;
    final id = await db.insert(
      'students',
      localStudent.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return localStudent.id != null
        ? localStudent
        : Student.fromMap(localStudent.toMap()..['id'] = id);
  }

  /// Fetches approved students in the organization who are NOT enrolled in the specific course.
  Future<List<Student>> getUnenrolledStudentsForCourse(int courseId, int organizationId) async {
    try {
      // 1. Fetch IDs of enrolled students from Supabase
      final enrolledResponse = await _supabase
          .from('course_students')
          .select('student_id')
          .eq('course_id', courseId);
      
      final List<int> enrolledIds = List<int>.from(enrolledResponse.map((item) => item['student_id'] as int));

      // 2. Fetch all approved students in organization
      var query = _supabase
          .from('students')
          .select()
          .eq('organization_id', organizationId)
          .eq('is_approved', 1);
      
      if (enrolledIds.isNotEmpty) {
        query = query.not('id', 'in', '(${enrolledIds.join(",")})');
      }

      final List<dynamic> response = await query.order('name');
      return response.map((item) => Student.fromMap(item as Map<String, dynamic>)).toList();
    } catch (e) {
      print('⚠️ Supabase fetch unenrolled students error: $e');
    }

    // Fallback to SQLite using NOT IN
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT * FROM students
      WHERE organization_id = ? AND is_approved = 1
      AND id NOT IN (
        SELECT student_id FROM course_students WHERE course_id = ?
      )
      ORDER BY name
      ''',
      [organizationId, courseId],
    );
    return List.generate(maps.length, (i) => Student.fromMap(maps[i]));
  }

  /// Fetches the course ID that a student is enrolled in.
  Future<int?> getEnrolledCourseId(int studentId) async {
    try {
      final response = await _supabase
          .from('course_students')
          .select('course_id')
          .eq('student_id', studentId)
          .maybeSingle();
      
      if (response != null && response['course_id'] != null) {
        return response['course_id'] as int;
      }
    } catch (e) {
      print('⚠️ Supabase getEnrolledCourseId error: $e');
    }

    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'course_students',
        columns: ['course_id'],
        where: 'student_id = ?',
        whereArgs: [studentId],
        limit: 1,
      );
      if (maps.isNotEmpty) {
        return maps.first['course_id'] as int?;
      }
    } catch (e) {
      print('⚠️ SQLite getEnrolledCourseId error: $e');
    }
    return null;
  }
}
