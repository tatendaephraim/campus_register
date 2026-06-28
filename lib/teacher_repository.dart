import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'database_helper.dart';
import 'teacher.dart';
import 'venue_repository.dart';

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
    final map = teacher.toMap();
    // Remove id if it is null so Supabase generates it
    if (teacher.id == null) {
      map.remove('id');
    }

    try {
      final response = await _supabase
          .from('teachers')
          .upsert(map, onConflict: 'email')
          .select()
          .single();

      supabaseTeacher = Teacher.fromMap(response);
      print('✅ Synced Teacher to Supabase: ${supabaseTeacher.name}');
    } on PostgrestException catch (e) {
      if (e.message.contains('teachers_office_venue_id_fkey')) {
        print('⚠️ Office venue missing in cloud. Attempting to sync venue first...');
        try {
          final officeId = teacher.officeVenueId;
          if (officeId != null) {
            final venueRepo = VenueRepository();
            final localVenue = await venueRepo.getVenueById(officeId);
            if (localVenue != null) {
               // Push venue to cloud
               await _supabase.from('venues').upsert(localVenue.toMap());
               print('✅ Auto-synced missing office venue: ${localVenue.name}');
               
               // Re-attempt original teacher sync
               final retryResponse = await _supabase
                  .from('teachers')
                  .upsert(map, onConflict: 'email')
                  .select()
                  .single();
               supabaseTeacher = Teacher.fromMap(retryResponse);
               print('✅ Teacher synced successfully after venue repair.');
               return supabaseTeacher;
            }
          }
          
          // Fallback if venue not found locally
          map['office_venue_id'] = null;
          final fallbackResponse = await _supabase.from('teachers').upsert(map, onConflict: 'email').select().single();
          supabaseTeacher = Teacher.fromMap(fallbackResponse);
        } catch (innerE) {
          print('⚠️ Failed venue-first repair sync: $innerE');
        }
      } else {
        print('⚠️ Supabase Teacher upsert error: $e');
      }
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
    final db = await dbHelper.database;
    
    // Check local first to see if we have an ID mismatch coming up
    final List<Map<String, dynamic>> localMaps = await db.query(
      'teachers',
      where: 'email = ?',
      whereArgs: [email],
    );
    int? localId = localMaps.isNotEmpty ? localMaps.first['id'] as int? : null;

    // Try Supabase first
    try {
      final response = await _supabase
          .from('teachers')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (response != null) {
        final teacher = Teacher.fromMap(response);
        int? supabaseId = teacher.id;

        // If ID changed (syncing from local to Supabase), migration is needed
        if (localId != null && supabaseId != null && localId != supabaseId) {
          print('🔄 Teacher ID migration: $localId -> $supabaseId');
          await db.transaction((txn) async {
            // Update all related tables that use teacher_id as a foreign key
            await txn.update('courses', {'teacher_id': supabaseId}, where: 'teacher_id = ?', whereArgs: [localId]);
            await txn.update('clock_logs', {'teacher_id': supabaseId}, where: 'teacher_id = ?', whereArgs: [localId]);
            await txn.update('attendance_waivers', {'teacher_id': supabaseId}, where: 'teacher_id = ?', whereArgs: [localId]);
            
            // Delete old record and insert new one
            await txn.delete('teachers', where: 'id = ?', whereArgs: [localId]);
          });
        }
        
        // ... local caching logic ...
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
      } else if (localMaps.isNotEmpty) {
        // CRITICAL FIX: Teacher is local but missing from Supabase. PUSH IT NOW.
        print('⚠️ Teacher found locally but missing from Supabase. Attempting repair sync...');
        final localTeacher = Teacher.fromMap(localMaps.first);
        return await upsertTeacher(localTeacher);
      }
    } catch (e) {
      print('⚠️ Supabase fetch teacher error: $e');
    }

    // Fallback to SQLite
    if (localMaps.isNotEmpty) {
      return Teacher.fromMap(localMaps.first);
    }
    throw Exception('Teacher not found');
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

  /// Fetches pending students for an organization.
  Future<List<Map<String, dynamic>>> getPendingStudents(
      int organizationId) async {
    try {
      final List<dynamic> response = await _supabase
          .from('students')
          .select()
          .eq('organization_id', organizationId)
          .filter('is_approved', 'is', null) // Fixed: use filter instead of is_ to check for null
          .order('name');

      final students = response.cast<Map<String, dynamic>>();

      // Cache all locally
      final db = await dbHelper.database;
      final batch = db.batch();
      for (var studentData in students) {
        // Ensure local cache has a representation of the student
        batch.insert('students', studentData,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);

      print(
          '✅ Fetched and cached ${students.length} pending students from Supabase.');
      return students;
    } catch (e) {
      print('⚠️ Supabase fetch pending students error: $e');
    }

    // Fallback to SQLite if Supabase fails
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: 'organization_id = ? AND (is_approved IS NULL OR is_approved = 0)',
      whereArgs: [organizationId],
      orderBy: 'name',
    );
    return maps;
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

  /// Fetches the name of the organization a teacher belongs to.
  ///
  /// This is useful for automatically populating fields like 'school_name'
  /// when creating new entities like a Course.
  Future<String?> getTeacherOrganizationName(int teacherId) async {
    try {
      // First, get the teacher's organization_id
      final teacherResponse = await _supabase
          .from('teachers')
          .select('organization_id')
          .eq('id', teacherId)
          .maybeSingle();

      if (teacherResponse == null || teacherResponse['organization_id'] == null)
        return null;

      final orgId = teacherResponse['organization_id'];

      // Then, fetch the organization's name using the ID
      final orgResponse = await _supabase
          .from('organizations')
          .select('name')
          .eq('id', orgId)
          .single();
      return orgResponse['name'] as String?;
    } catch (e) {
      print('⚠️ Supabase getTeacherOrganizationName error: $e');
      return null;
    }
  }
}
