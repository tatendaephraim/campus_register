import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_helper.dart';
import 'clock_log.dart';

class ClockLogRepository {
  final _supabase = Supabase.instance.client;
  final dbHelper = DatabaseHelper.instance;

  /// Inserts a new clock-in entry.
  Future<ClockLog> clockIn({int? teacherId, int? studentId, required String type, int? venueId}) async {
    final nowStr = DateTime.now().toIso8601String();
    final log = ClockLog(
      teacherId: teacherId,
      studentId: studentId,
      type: type,
      venueId: venueId,
      clockIn: nowStr,
    );

    // 1. Try Supabase first
    ClockLog? supabaseLog;
    try {
      final response = await _supabase
          .from('clock_logs')
          .insert(log.toMap()..remove('id'))
          .select()
          .single();
      supabaseLog = ClockLog.fromMap(response);
      print('✅ Synced clock-in to Supabase');
    } catch (e) {
      print('⚠️ Supabase clock-in error: $e');
    }

    // 2. Save locally
    final localLog = supabaseLog ?? log;
    final db = await dbHelper.database;
    final id = await db.insert(
      'clock_logs',
      localLog.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return localLog.id != null ? localLog : ClockLog.fromMap(localLog.toMap()..['id'] = id);
  }

  /// Updates clock-out timestamp.
  Future<void> clockOut(int logId, {String? earlyLeaveReason}) async {
    final nowStr = DateTime.now().toIso8601String();
    final updates = {
      'clock_out': nowStr,
      if (earlyLeaveReason != null) 'early_leave_reason': earlyLeaveReason,
    };

    // 1. Try Supabase
    try {
      await _supabase
          .from('clock_logs')
          .update(updates)
          .eq('id', logId);
      print('✅ Synced clock-out to Supabase');
    } catch (e) {
      print('⚠️ Supabase clock-out error: $e');
    }

    // 2. Save locally
    final db = await dbHelper.database;
    await db.update(
      'clock_logs',
      updates,
      where: 'id = ?',
      whereArgs: [logId],
    );
  }

  /// Fetches an active clock-in log of a specific type (e.g. office, venue).
  Future<ClockLog?> getActiveLog({int? teacherId, int? studentId, required String type}) async {
    // 1. Try Supabase
    try {
      final List<dynamic> response = await _supabase
          .from('clock_logs')
          .select()
          .eq('type', type)
          .filter('clock_out', 'is', null)
          .eq(teacherId != null ? 'teacher_id' : 'student_id', (teacherId ?? studentId)!)
          .timeout(const Duration(seconds: 8));

      if (response.isNotEmpty) {
        return ClockLog.fromMap(response.first as Map<String, dynamic>);
      }
    } catch (e) {
      print('⚠️ Supabase getActiveLog error: $e');
    }

    // 2. Fallback to SQLite
    final db = await dbHelper.database;
    final queryField = teacherId != null ? 'teacher_id' : 'student_id';
    final List<Map<String, dynamic>> maps = await db.query(
      'clock_logs',
      where: 'type = ? AND clock_out IS NULL AND $queryField = ?',
      whereArgs: [type, teacherId ?? studentId],
    );

    if (maps.isNotEmpty) {
      return ClockLog.fromMap(maps.first);
    }
    return null;
  }

  /// Approves early leave early.
  Future<void> approveEarlyLeave(int logId) async {
    try {
      await _supabase
          .from('clock_logs')
          .update({'early_leave_approved': 1})
          .eq('id', logId);
      print('✅ Approved early leave on Supabase');
    } catch (e) {
      print('⚠️ Supabase approveEarlyLeave error: $e');
    }

    final db = await dbHelper.database;
    await db.update(
      'clock_logs',
      {'early_leave_approved': 1},
      where: 'id = ?',
      whereArgs: [logId],
    );
  }

  /// Fetches all logs for a user.
  Future<List<ClockLog>> getLogs({int? teacherId, int? studentId}) async {
    final queryField = teacherId != null ? 'teacher_id' : 'student_id';
    try {
      final List<dynamic> response = await _supabase
          .from('clock_logs')
          .select()
          .eq(queryField, (teacherId ?? studentId)!)
          .order('clock_in', ascending: false);
      return response.map((item) => ClockLog.fromMap(item as Map<String, dynamic>)).toList();
    } catch (e) {
      print('⚠️ Supabase getLogs error: $e');
    }

    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'clock_logs',
      where: '$queryField = ?',
      whereArgs: [teacherId ?? studentId],
      orderBy: 'clock_in DESC',
    );
    return List.generate(maps.length, (i) => ClockLog.fromMap(maps[i]));
  }

  /// Fetches aggregated clock statistics for all employees in an organization.
  Future<Map<String, int>> getOrganizationClockStats(int orgId, {String period = 'all'}) async {
    final db = await dbHelper.database;
    String dateFilter = '';
    if (period == 'weekly') {
      dateFilter = "AND cl.clock_in >= datetime('now', '-7 days')";
    } else if (period == 'monthly') {
      dateFilter = "AND cl.clock_in >= datetime('now', '-30 days')";
    } else if (period == 'yearly') {
      dateFilter = "AND cl.clock_in >= datetime('now', '-365 days')";
    }

    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT cl.clock_out, COUNT(*) as count 
      FROM clock_logs cl
      INNER JOIN teachers t ON cl.teacher_id = t.id
      WHERE t.organization_id = ? AND cl.type = 'office' $dateFilter
      GROUP BY (cl.clock_out IS NULL)
    ''', [orgId]);

    final Map<String, int> stats = {'CLOCKED_IN': 0, 'CLOCKED_OUT': 0};
    for (var row in results) {
      final clockOut = row['clock_out'] as String?;
      final count = row['count'] as int;
      if (clockOut == null || clockOut.isEmpty) {
        stats['CLOCKED_IN'] = stats['CLOCKED_IN']! + count;
      } else {
        stats['CLOCKED_OUT'] = stats['CLOCKED_OUT']! + count;
      }
    }
    return stats;
  }

  /// Fetches the clock-in trend (compliance rate by day) for all employees in an organization.
  Future<Map<String, double>> getOrganizationClockTrend(int orgId, {String period = 'all'}) async {
    final db = await dbHelper.database;
    String dateFilter = '';
    int limitCount = 7;
    if (period == 'weekly') {
      dateFilter = "AND cl.clock_in >= datetime('now', '-7 days')";
      limitCount = 7;
    } else if (period == 'monthly') {
      dateFilter = "AND cl.clock_in >= datetime('now', '-30 days')";
      limitCount = 30;
    } else if (period == 'yearly') {
      dateFilter = "AND cl.clock_in >= datetime('now', '-365 days')";
      limitCount = 12;
    }

    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT DATE(cl.clock_in) as date_day,
             COUNT(DISTINCT cl.teacher_id) * 1.0 / (
               SELECT COUNT(*) FROM teachers WHERE organization_id = ? AND is_approved = 1
             ) as active_rate
      FROM clock_logs cl
      INNER JOIN teachers t ON cl.teacher_id = t.id
      WHERE t.organization_id = ? AND cl.type = 'office' $dateFilter
      GROUP BY date_day
      ORDER BY date_day ASC
      LIMIT $limitCount
    ''', [orgId, orgId]);

    final Map<String, double> trend = {};
    for (var row in results) {
      final date = row['date_day'] as String;
      final rate = (row['active_rate'] as num).toDouble();
      trend[date] = rate;
    }
    return trend;
  }
}
