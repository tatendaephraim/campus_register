import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_helper.dart';
import 'timetable_constraints.dart';
import 'timetable_day_override.dart';

class TimetableConstraintsRepository {
  final _supabase = Supabase.instance.client;
  final dbHelper = DatabaseHelper.instance;

  // ─────────────────────────────────────────────────────────────────────────────
  // Global constraints (shift hours, breaks, lunch, assembly)
  // ─────────────────────────────────────────────────────────────────────────────

  /// Fetches constraints for an organization, first trying Supabase then SQLite.
  Future<TimetableConstraints?> getConstraints(int organizationId) async {
    // 1. Try Supabase first
    try {
      final List<dynamic> response = await _supabase
          .from('timetable_constraints')
          .select()
          .eq('organization_id', organizationId)
          .timeout(const Duration(seconds: 8));

      if (response.isNotEmpty) {
        final constraints = TimetableConstraints.fromMap(response.first as Map<String, dynamic>);
        // Cache locally
        final db = await dbHelper.database;
        await db.insert('timetable_constraints', constraints.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        return constraints;
      }
    } catch (e) {
      debugPrint('⚠️ Supabase fetch constraints error: $e');
    }

    // 2. Fallback to SQLite
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'timetable_constraints',
      where: 'organization_id = ?',
      whereArgs: [organizationId],
    );

    if (maps.isNotEmpty) {
      return TimetableConstraints.fromMap(maps.first);
    }
    return null;
  }

  /// Saves or updates constraints both on Supabase and SQLite.
  Future<void> saveConstraints(TimetableConstraints constraints) async {
    // 1. Try Supabase first
    try {
      final map = constraints.toMap();
      if (constraints.id == null) {
        map.remove('id');
      }

      await _supabase
          .from('timetable_constraints')
          .upsert(map, onConflict: 'organization_id');
      debugPrint('✅ Synced timetable constraints to Supabase');
    } catch (e) {
      debugPrint('⚠️ Supabase save constraints error: $e');
    }

    // 2. Save to local SQLite
    final db = await dbHelper.database;
    await db.insert(
      'timetable_constraints',
      constraints.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Day-of-week overrides
  // ─────────────────────────────────────────────────────────────────────────────

  /// Returns all 7 day overrides for an organisation.
  /// Missing days (not yet saved) will not be in the list — callers should use
  /// [getOrBuildDefaultOverrides] to always get a full 7-day list.
  Future<List<TimetableDayOverride>> getDayOverrides(int organizationId) async {
    // 1. Try Supabase
    try {
      final List<dynamic> response = await _supabase
          .from('timetable_day_overrides')
          .select()
          .eq('organization_id', organizationId)
          .order('day_of_week')
          .timeout(const Duration(seconds: 8));

      if (response.isNotEmpty) {
        final overrides = response
            .map((e) => TimetableDayOverride.fromMap(e as Map<String, dynamic>))
            .toList();
        // Cache locally
        final db = await dbHelper.database;
        for (final o in overrides) {
          await db.insert('timetable_day_overrides', o.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        return overrides;
      }
    } catch (e) {
      debugPrint('⚠️ Supabase fetch day overrides error: $e');
    }

    // 2. Fallback to SQLite
    final db = await dbHelper.database;
    final maps = await db.query(
      'timetable_day_overrides',
      where: 'organization_id = ?',
      whereArgs: [organizationId],
      orderBy: 'day_of_week',
    );
    return maps.map((m) => TimetableDayOverride.fromMap(m)).toList();
  }

  /// Returns a full 7-day list (Mon–Sun) with sensible defaults for any day
  /// that hasn't been explicitly saved yet.
  /// Defaults: Mon–Fri = working, Sat–Sun = non-working ("Weekend").
  Future<List<TimetableDayOverride>> getOrBuildDefaultOverrides(
      int organizationId) async {
    final saved = await getDayOverrides(organizationId);
    final savedByDay = {for (final o in saved) o.dayOfWeek: o};

    return List.generate(7, (i) {
      final day = i + 1; // 1=Mon … 7=Sun
      return savedByDay[day] ??
          TimetableDayOverride(
            organizationId: organizationId,
            dayOfWeek: day,
            isWorkingDay: day <= 5, // Mon–Fri working, Sat–Sun not
            label: day >= 6 ? 'Weekend' : null,
          );
    });
  }

  /// Saves a single day override to both Supabase and SQLite.
  Future<void> upsertDayOverride(TimetableDayOverride override) async {
    // 1. Try Supabase
    try {
      final map = override.toMap();
      map.remove('id');
      await _supabase
          .from('timetable_day_overrides')
          .upsert(map, onConflict: 'organization_id,day_of_week');
      debugPrint('✅ Synced day override (day ${override.dayOfWeek}) to Supabase');
    } catch (e) {
      debugPrint('⚠️ Supabase upsert day override error: $e');
    }

    // 2. Save to SQLite
    final db = await dbHelper.database;
    await db.insert(
      'timetable_day_overrides',
      override.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Saves all 7 day overrides in a single batch operation.
  Future<void> saveAllDayOverrides(List<TimetableDayOverride> overrides) async {
    for (final o in overrides) {
      await upsertDayOverride(o);
    }
  }

  /// Returns the override for a specific day, or a default if not set.
  Future<TimetableDayOverride> getDayOverride(
      int organizationId, int dayOfWeek) async {
    final db = await dbHelper.database;

    // Try local first (fast path)
    final maps = await db.query(
      'timetable_day_overrides',
      where: 'organization_id = ? AND day_of_week = ?',
      whereArgs: [organizationId, dayOfWeek],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return TimetableDayOverride.fromMap(maps.first);
    }

    // Default: weekdays are working, weekends are not
    return TimetableDayOverride(
      organizationId: organizationId,
      dayOfWeek: dayOfWeek,
      isWorkingDay: dayOfWeek <= 5,
      label: dayOfWeek >= 6 ? 'Weekend' : null,
    );
  }
}
