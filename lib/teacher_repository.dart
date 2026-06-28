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

  /// Fetches a single teacher from the database by their ID.
  Future<Teacher?> getTeacherById(int id) async {
    try {
      // First, check if any venues exist for the organization to prevent incorrect office allocation.
      final teacherForOrg = await _supabase
          .from('teachers')
          .select('organization_id')
          .eq('id', id)
          .maybeSingle();
      if (teacherForOrg != null && teacherForOrg['organization_id'] != null) {
        final venueCount = await _supabase
            .from('venues')
            .count(CountOption.exact)
            .eq('organization_id', teacherForOrg['organization_id']);
        if (venueCount == 0) {
          // No venues exist, so ensure office_venue_id is null.
          await _supabase
              .from('teachers')
              .update({'office_venue_id': null}).eq('id', id);
          // Also update the local cache to reflect this change immediately.
          final db = await dbHelper.database;
          await db.update('teachers', {'office_venue_id': null},
              where: 'id = ?', whereArgs: [id]);
        }
      }

      final response =
          await _supabase.from('teachers').select().eq('id', id).maybeSingle();
      if (response != null) {
        final teacher = Teacher.fromMap(response);
        final db = await dbHelper.database;
        final List<Map<String, dynamic>> local = await db.query(
          'teachers',
          columns: ['office_venue_id'],
          where: 'id = ?',
          whereArgs: [id],
        );
        int? localOfficeId;
        if (local.isNotEmpty) {
          localOfficeId = local.first['office_venue_id'] as int?;
        }

        final map = teacher.toMap();
        if (map['office_venue_id'] == null && localOfficeId != null) {
          map['office_venue_id'] = localOfficeId;
        }

        await db.insert('teachers', map,
            conflictAlgorithm: ConflictAlgorithm.replace);
        return Teacher.fromMap(map);
      }
    } catch (e) {
      print('⚠️ Supabase fetch teacher by ID error: $e');
    }

    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'teachers',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Teacher.fromMap(maps.first);
    }
    return null;
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
        final List<Map<String, dynamic>> local = await db.query(
          'teachers',
          columns: ['office_venue_id'],
          where: 'email = ?',
          whereArgs: [email],
        );
        int? localOfficeId;
        if (local.isNotEmpty) {
          localOfficeId = local.first['office_venue_id'] as int?;
        }

        final map = teacher.toMap();
        if (map['office_venue_id'] == null && localOfficeId != null) {
          map['office_venue_id'] = localOfficeId;
        }

        await db.insert(
          'teachers',
          map,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return Teacher.fromMap(map);
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
      final List<dynamic> response =
          await _supabase.from('teachers').select().order('name');

      final teachers = response
          .map((item) => Teacher.fromMap(item as Map<String, dynamic>))
          .toList();

      // Cache all locally
      final db = await dbHelper.database;
      final batch = db.batch();
      for (var teacher in teachers) {
        batch.insert('teachers', teacher.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);

      return teachers;
    } catch (e) {
      print('⚠️ Supabase fetch all teachers error: $e');
    }

    // Fallback to SQLite
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps =
        await db.query('teachers', orderBy: 'name');
    return List.generate(maps.length, (i) => Teacher.fromMap(maps[i]));
  }

  /// Fetches pending employees for an organization.
  Future<List<Teacher>> getPendingEmployees(int organizationId) async {
    try {
      final List<dynamic> response = await _supabase
          .from('teachers')
          .select()
          .eq('organization_id', organizationId)
          .eq('is_approved', 0)
          .order('name');
      final teachers = response
          .map((item) => Teacher.fromMap(item as Map<String, dynamic>))
          .toList();

      final db = await dbHelper.database;
      final batch = db.batch();
      for (var teacher in teachers) {
        final List<Map<String, dynamic>> local = await db.query(
          'teachers',
          columns: ['office_venue_id'],
          where: 'id = ?',
          whereArgs: [teacher.id],
        );
        int? localOfficeId;
        if (local.isNotEmpty) {
          localOfficeId = local.first['office_venue_id'] as int?;
        }

        final map = teacher.toMap();
        if (map['office_venue_id'] == null && localOfficeId != null) {
          map['office_venue_id'] = localOfficeId;
        }

        batch.insert('teachers', map,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    } catch (e) {
      print('⚠️ Supabase fetch pending employees error: $e');
    }

    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'teachers',
      where: 'organization_id = ? AND is_approved = 0',
      whereArgs: [organizationId],
      orderBy: 'name',
    );
    return List.generate(maps.length, (i) => Teacher.fromMap(maps[i]));
  }

  /// Fetches approved employees for an organization.
  Future<List<Teacher>> getApprovedEmployees(int organizationId) async {
    try {
      final List<dynamic> response = await _supabase
          .from('teachers')
          .select()
          .eq('organization_id', organizationId)
          .eq('is_approved', 1)
          .order('name');
      final teachers = response
          .map((item) => Teacher.fromMap(item as Map<String, dynamic>))
          .toList();

      final db = await dbHelper.database;
      final batch = db.batch();
      for (var teacher in teachers) {
        final List<Map<String, dynamic>> local = await db.query(
          'teachers',
          columns: ['office_venue_id'],
          where: 'id = ?',
          whereArgs: [teacher.id],
        );
        int? localOfficeId;
        if (local.isNotEmpty) {
          localOfficeId = local.first['office_venue_id'] as int?;
        }

        final map = teacher.toMap();
        if (map['office_venue_id'] == null && localOfficeId != null) {
          map['office_venue_id'] = localOfficeId;
        }

        batch.insert('teachers', map,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    } catch (e) {
      print('⚠️ Supabase fetch approved employees error: $e');
    }

    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'teachers',
      where: 'organization_id = ? AND is_approved = 1',
      whereArgs: [organizationId],
      orderBy: 'name',
    );
    return List.generate(maps.length, (i) => Teacher.fromMap(maps[i]));
  }

  /// Approves a pending employee and assigns their role.
  Future<void> approveEmployee(int employeeId, String role) async {
    try {
      await _supabase
          .from('teachers')
          .update({'is_approved': 1, 'role': role}).eq('id', employeeId);
      print('✅ Approved employee $employeeId on Supabase with role: $role');
    } catch (e) {
      print('⚠️ Supabase approve employee error: $e');
    }

    final db = await dbHelper.database;
    await db.update(
      'teachers',
      {'is_approved': 1, 'role': role},
      where: 'id = ?',
      whereArgs: [employeeId],
    );
  }

  /// Rejects (deletes) a pending employee.
  Future<void> rejectEmployee(int employeeId) async {
    try {
      await _supabase.from('teachers').delete().eq('id', employeeId);
      print('✅ Rejected and deleted employee $employeeId from Supabase');
    } catch (e) {
      print('⚠️ Supabase reject employee error: $e');
    }

    final db = await dbHelper.database;
    await db.delete(
      'teachers',
      where: 'id = ?',
      whereArgs: [employeeId],
    );
  }

  /// Updates a teacher's device app ID (unique mobile ID).
  Future<void> updateTeacherDeviceId(int teacherId, String deviceId) async {
    try {
      await _supabase
          .from('teachers')
          .update({'device_app_id': deviceId}).eq('id', teacherId);
      print('✅ Updated teacher device ID on Supabase');
    } catch (e) {
      print('⚠️ Supabase updateTeacherDeviceId error: $e');
    }

    final db = await dbHelper.database;
    await db.update(
      'teachers',
      {'device_app_id': deviceId},
      where: 'id = ?',
      whereArgs: [teacherId],
    );
  }

  /// Updates a teacher's allocated office venue.
  Future<void> updateTeacherOfficeVenue(int teacherId, int? venueId) async {
    try {
      await _supabase
          .from('teachers')
          .update({'office_venue_id': venueId}).eq('id', teacherId);
      print('✅ Updated teacher office venue on Supabase');
    } catch (e) {
      print('⚠️ Supabase updateTeacherOfficeVenue error: $e');
    }

    final db = await dbHelper.database;
    await db.update(
      'teachers',
      {'office_venue_id': venueId},
      where: 'id = ?',
      whereArgs: [teacherId],
    );
  }

  /// Updates teacher metadata details.
  Future<void> updateTeacher(Teacher teacher) async {
    try {
      await _supabase.from('teachers').update({
        'name': teacher.name,
        'email': teacher.email,
        'role': teacher.role,
      }).eq('id', teacher.id!);
      print('✅ Updated teacher metadata on Supabase');
    } catch (e) {
      print('⚠️ Supabase updateTeacher error: $e');
    }

    final db = await dbHelper.database;
    await db.update(
      'teachers',
      {
        'name': teacher.name,
        'email': teacher.email,
        'role': teacher.role,
      },
      where: 'id = ?',
      whereArgs: [teacher.id],
    );
  }

  /// Suspends (blocks) a teacher by revoking approval.
  Future<void> suspendTeacher(int teacherId) async {
    try {
      await _supabase
          .from('teachers')
          .update({'is_approved': 0}).eq('id', teacherId);
      print('✅ Suspended teacher $teacherId on Supabase');
    } catch (e) {
      print('⚠️ Supabase suspendTeacher error: $e');
    }

    final db = await dbHelper.database;
    await db.update(
      'teachers',
      {'is_approved': 0},
      where: 'id = ?',
      whereArgs: [teacherId],
    );
  }
}
