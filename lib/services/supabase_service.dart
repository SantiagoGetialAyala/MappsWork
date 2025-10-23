// lib/services/supabase_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

class SupabaseService {
  static const String supabaseUrl = 'https://skylhfvxtsrznncvbnjg.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNreWxoZnZ4dHNyem5uY3ZibmpnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjExNTcyMDUsImV4cCI6MjA3NjczMzIwNX0.5l5Pl1qxX009BFKIY-5hLDTh6eY2VRIyfj2zx_f0sN8';

  static late final SupabaseClient client;

  static Future<void> init() async {
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      client = Supabase.instance.client;
      print('✅ Supabase initialized successfully');
    } catch (e) {
      print('❌ Error initializing Supabase: $e');
      rethrow;
    }
  }

  // ======================
  // MARKERS (rutas_residuos)
  // ======================
  Future<List<Map<String, dynamic>>> getMarkers() async {
    try {
      final resp = await client.from('rutas_residuos').select();
      // Normalize to {lat,lng,descripcion,id}
      return (resp as List).map((r) {
        return {
          'id': r['id'],
          'lat': r['lat'],
          'lng': r['lng'],
          'descripcion': r['descripcion'] ?? r['descripcion'] ?? r['descripcion'],
        };
      }).cast<Map<String, dynamic>>().toList();
    } catch (e) {
      print('⚠️ getMarkers error (maybe table missing): $e');
      return [];
    }
  }

  Future<bool> addMarker(double lat, double lng, String descripcion) async {
    try {
      await client.from('rutas_residuos').insert({
        'lat': lat,
        'lng': lng,
        'descripcion': descripcion,
        'created_at': DateTime.now().toIso8601String(),
      });
      print('✅ Marker inserted');
      return true;
    } catch (e) {
      print('! Error adding marker: $e');
      return false;
    }
  }

  // ======================
  // ROUTES (rutas_eco)
  // ======================
  Future<List<Map<String, dynamic>>> getSavedRoutes() async {
    try {
      final resp = await client.from('rutas_eco').select();
      return (resp as List).map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (e) {
      print('⚠️ getSavedRoutes error: $e');
      return [];
    }
  }

  /// path: a list of [ [lon,lat], [lon,lat], ... ] or list of {lat:..,lng:..}
  Future<bool> addRoute({
    required String name,
    required String description,
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    required List<List<double>> path,
  }) async {
    try {
      await client.from('rutas_eco').insert({
        'name': name,
        'description': description,
        'start_lat': startLat,
        'start_lng': startLng,
        'end_lat': endLat,
        'end_lng': endLng,
        'path': jsonEncode(path),
        'created_at': DateTime.now().toIso8601String(),
      });
      print('✅ Route saved');
      return true;
    } catch (e) {
      print('! Error saving route: $e');
      return false;
    }
  }
}
