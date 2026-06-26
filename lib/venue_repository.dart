import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'database_helper.dart';
import 'venue.dart';

/// Repository for handling data operations for the [Venue] model.
class VenueRepository {
  final dbHelper = DatabaseHelper.instance;
  final _supabase = Supabase.instance.client;

  /// Inserts or updates a venue in the database.
  ///
  /// Synchronizes with Supabase when online, and caches the result locally.
  Future<Venue> upsertVenue(Venue venue) async {
    final db = await dbHelper.database;

    // 1. Try syncing to Supabase if online
    Venue? supabaseVenue;
    try {
      final map = venue.toMap();
      if (venue.id == null) {
        map.remove('id');
      }

      final response = await _supabase
          .from('venues')
          .upsert(map)
          .select()
          .single();
      
      supabaseVenue = Venue.fromMap(response);
      print('✅ Synced Venue to Supabase: ${supabaseVenue.name}');
    } catch (e) {
      print('⚠️ Supabase Venue upsert error: $e');
    }

    // 2. Save locally (using Supabase-generated ID if available)
    final localVenue = supabaseVenue ?? venue;
    final id = await db.insert(
      'venues',
      localVenue.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (localVenue.id != null) {
      return localVenue;
    } else {
      return Venue.fromMap(localVenue.toMap()..['id'] = id);
    }
  }

  /// Fetches all venues from the database.
  Future<List<Venue>> getAllVenues() async {
    // Try Supabase first
    try {
      final List<dynamic> response = await _supabase
          .from('venues')
          .select()
          .order('name');
      
      final venues = response.map((item) => Venue.fromMap(item as Map<String, dynamic>)).toList();

      // Cache all locally
      final db = await dbHelper.database;
      final batch = db.batch();
      for (var venue in venues) {
        batch.insert('venues', venue.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);

      return venues;
    } catch (e) {
      print('⚠️ Supabase fetch all venues error: $e');
    }

    // Fallback to SQLite
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps =
        await db.query('venues', orderBy: 'name');
    return List.generate(maps.length, (i) => Venue.fromMap(maps[i]));
  }

  /// Fetches a single venue by its ID.
  Future<Venue?> getVenueById(int venueId) async {
    // Try Supabase first
    try {
      final response = await _supabase
          .from('venues')
          .select()
          .eq('id', venueId)
          .maybeSingle();
      
      if (response != null) {
        final venue = Venue.fromMap(response);
        // Cache locally
        final db = await dbHelper.database;
        await db.insert(
          'venues',
          venue.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return venue;
      }
    } catch (e) {
      print('⚠️ Supabase fetch venue by ID error: $e');
    }

    // Fallback to SQLite
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'venues',
      where: 'id = ?',
      whereArgs: [venueId],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Venue.fromMap(maps.first);
    }
    return null;
  }

  /// Deletes a venue from both the database and Supabase.
  Future<void> deleteVenue(int venueId) async {
    final db = await dbHelper.database;

    // 1. Try deleting from Supabase
    try {
      await _supabase.from('venues').delete().eq('id', venueId);
      print('✅ Deleted Venue from Supabase: $venueId');
    } catch (e) {
      print('⚠️ Supabase Venue delete error: $e');
    }

    // 2. Delete locally
    await db.delete(
      'venues',
      where: 'id = ?',
      whereArgs: [venueId],
    );
  }
}
