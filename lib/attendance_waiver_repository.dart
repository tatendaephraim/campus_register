import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_helper.dart';
import 'attendance_waiver.dart';

class AttendanceWaiverRepository {
  final _supabase = Supabase.instance.client;
  final dbHelper = DatabaseHelper.instance;

  /// Submits a new waiver request.
  Future<AttendanceWaiver> submitWaiver(AttendanceWaiver waiver) async {
    // 1. Try Supabase first
    AttendanceWaiver? supabaseWaiver;
    try {
      final response = await _supabase
          .from('attendance_waivers')
          .insert(waiver.toMap()..remove('id'))
          .select()
          .single();
      supabaseWaiver = AttendanceWaiver.fromMap(response);
      print('✅ Synced waiver to Supabase');
    } catch (e) {
      print('⚠️ Supabase waiver insert error: $e');
    }

    // 2. Save locally
    final localWaiver = supabaseWaiver ?? waiver;
    final db = await dbHelper.database;
    final id = await db.insert(
      'attendance_waivers',
      localWaiver.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return localWaiver.id != null ? localWaiver : AttendanceWaiver.fromMap(localWaiver.toMap()..['id'] = id);
  }

  /// Fetches waivers for a student.
  Future<List<AttendanceWaiver>> getWaiversForStudent(int studentId) async {
    try {
      final List<dynamic> response = await _supabase
          .from('attendance_waivers')
          .select()
          .eq('student_id', studentId);
      return response.map((item) => AttendanceWaiver.fromMap(item as Map<String, dynamic>)).toList();
    } catch (e) {
      print('⚠️ Supabase fetch waivers error: $e');
    }

    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance_waivers',
      where: 'student_id = ?',
      whereArgs: [studentId],
    );
    return List.generate(maps.length, (i) => AttendanceWaiver.fromMap(maps[i]));
  }
}
