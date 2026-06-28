import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_helper.dart';
import 'organization.dart';

class OrganizationRepository {
  final _supabase = Supabase.instance.client;
  final dbHelper = DatabaseHelper.instance;

  /// Generates a random 9-character alphanumeric organization code.
  String generateOrganizationCode() {
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(9, (index) => chars[random.nextInt(chars.length)]).join();
  }

  /// Syncs an organization to Supabase (if online) and caches it locally.
  Future<Organization> createOrganization(Organization org) async {
    // 1. Try syncing to Supabase if online
    Organization? supabaseOrg;
    try {
      final response = await _supabase
          .from('organizations')
          .insert(org.toMap()..remove('id'))
          .select()
          .single()
          .timeout(const Duration(seconds: 8));

      supabaseOrg = Organization.fromMap(response);
      print('✅ Synced Organization to Supabase: ${supabaseOrg.name}');
    } catch (e) {
      print('⚠️ Supabase Organization insert error: $e');
    }

    // 2. Save locally (using Supabase-generated ID if available)
    final localOrg = supabaseOrg ?? org;
    final db = await dbHelper.database;
    final id = await db.insert(
      'organizations',
      localOrg.toMap()..remove('id'), // Let SQLite auto-increment if no Supabase ID
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (localOrg.id == null) {
      return Organization.fromMap(localOrg.toMap()..['id'] = id);
    } else {
      return localOrg;
    }
  }

  /// Fetches an organization by its unique 9-character code.
  Future<Organization?> getOrganizationByCode(String code) async {
    final cleanCode = code.trim().toUpperCase();

    // 1. Try Supabase first
    try {
      final List<dynamic> response = await _supabase
          .from('organizations')
          .select()
          .eq('code', cleanCode)
          .timeout(const Duration(seconds: 8));

      if (response.isNotEmpty) {
        final org = Organization.fromMap(response.first as Map<String, dynamic>);
        // Cache locally
        final db = await dbHelper.database;
        await db.insert('organizations', org.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        return org;
      }
    } catch (e) {
      print('⚠️ Supabase fetch organization by code error: $e');
    }

    // 2. Fallback to local db
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'organizations',
      where: 'code = ?',
      whereArgs: [cleanCode],
    );

    if (maps.isNotEmpty) {
      return Organization.fromMap(maps.first);
    }
    return null;
  }

  /// Fetches an organization by its ID.
  Future<Organization?> getOrganizationById(int id) async {
    // Try Supabase first
    try {
      final response = await _supabase
          .from('organizations')
          .select()
          .eq('id', id)
          .single()
          .timeout(const Duration(seconds: 8));

      final org = Organization.fromMap(response);
      final db = await dbHelper.database;
      await db.insert('organizations', org.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      return org;
    } catch (e) {
      print('⚠️ Supabase fetch organization by ID error: $e');
    }

    // Fallback to local db
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'organizations',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Organization.fromMap(maps.first);
    }
    return null;
  }
}
