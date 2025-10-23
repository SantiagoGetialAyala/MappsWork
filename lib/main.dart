import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Constante para el nombre de la tabla.
// Asegúrate que este nombre coincida EXACTAMENTE con tu tabla en Supabase.
const String _kTableName = 'rutas_ecologicas'; // ¡Cambia esto si tu tabla se llama diferente!

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Tu URL y Anon Key proporcionadas
  await Supabase.initialize(
    url: 'https://qcnixlaxukshzzdjelgr.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFjbml4bGF4dWtzaHp6ZGplbGdyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjExNjA3MjAsImV4cCI6MjA3NjczNjcyMH0.-dH1LB_AmaZrtevcUoGrEHkl5-WxuF9wuMwi-SJcFWk',
  );

  runApp(const EcoRutasApp());
}

final supabase = Supabase.instance.client;

class EcoRutasApp extends StatelessWidget {
  const EcoRutasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoRutas Nariño',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(primary: Colors.green),
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  LatLng? startPoint;
  LatLng? endPoint;
  List<LatLng> routePoints = [];
  List<Map<String, dynamic>> savedRoutes = [];
  bool loading = true;
  String? errorMessage; // Para mostrar errores de Supabase

  @override
  void initState() {
    super.initState();
    loadSavedRoutes();
  }

  // 🔹 Cargar rutas guardadas
  Future<void> loadSavedRoutes() async {
    setState(() {
      loading = true;
      errorMessage = null; // Limpiar error previo
    });
    try {
      final data = await supabase
          .from(_kTableName) // Usa la constante corregida
          .select()
          .order('created_at', ascending: false);

      setState(() {
        savedRoutes = List<Map<String, dynamic>>.from(data);
        loading = false;
      });
    } on PostgrestException catch (e) {
      // Captura el error específico de la base de datos
      debugPrint('⚠️ Error al cargar rutas (Postgrest): $e');
      setState(() {
        errorMessage =
            'Error al cargar rutas: ${e.message}. Verifica que la tabla "$_kTableName" exista.';
        loading = false;
      });
    } catch (e) {
      // Captura otros errores
      debugPrint('⚠️ Error al cargar rutas: $e');
      setState(() {
        errorMessage = 'Error desconocido al cargar rutas: $e';
        loading = false;
      });
    }
  }

  // 🔹 Obtener ruta desde API de OSRM
  Future<void> _getRouteFromAPI() async {
    if (startPoint == null || endPoint == null) return;
    final url =
        'https://router.project-osrm.org/route/v1/driving/${startPoint!.longitude},${startPoint!.latitude};${endPoint!.longitude},${endPoint!.latitude}?overview=full&geometries=geojson';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // OSRM devuelve [lng, lat], Flutter_map espera LatLng(lat, lng)
      final coords = data['routes'][0]['geometry']['coordinates'] as List;
      setState(() {
        routePoints = coords
            .map((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
            .toList();
      });
    } else {
      debugPrint('❌ Error al obtener ruta de OSRM');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Error al calcular la ruta de OSRM")),
        );
      }
    }
  }

  // 🔹 Manejar taps en el mapa
  void _handleTap(LatLng point) {
    setState(() {
      if (startPoint == null) {
        startPoint = point;
      } else if (endPoint == null) {
        endPoint = point;
        _getRouteFromAPI();
      } else {
        // Reiniciar la selección
        startPoint = point;
        endPoint = null;
        routePoints = [];
      }
    });
  }

  // 🔹 Guardar una nueva ruta
  Future<void> _saveRouteDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    if (startPoint == null || endPoint == null || routePoints.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Selecciona una ruta válida (Inicio y Fin) antes de guardar.")),
        );
      }
      return;
    }

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("💾 Guardar nueva ruta",
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Nombre de la ruta",
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Descripción",
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar",
                style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.isEmpty ||
                  descController.text.isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Completa todos los campos.")),
                  );
                }
                return;
              }

              try {
                await supabase.from(_kTableName).insert({
                  'nombre': nameController.text.trim(),
                  'descripcion': descController.text.trim(),
                  'lat_inicio': startPoint!.latitude,
                  'lng_inicio': startPoint!.longitude,
                  'lat_fin': endPoint!.latitude,
                  'lng_fin': endPoint!.longitude,
                });

                if (mounted) {
                  Navigator.pop(ctx);
                  await loadSavedRoutes();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("✅ Ruta guardada correctamente")),
                  );
                }
              } catch (e) {
                debugPrint('❌ Error al guardar en Supabase: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text("❌ Error al guardar: $e")),
                  );
                }
              }
            },
            child: const Text("Guardar",
                style: TextStyle(color: Colors.greenAccent)),
          ),
        ],
      ),
    );
  }

  // 🔹 Eliminar una ruta
  Future<void> _deleteRoute(String routeId) async {
    try {
      await supabase.from(_kTableName).delete().eq('id', routeId);
      await loadSavedRoutes(); // Recargar la lista
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🗑️ Ruta eliminada correctamente")),
        );
      }
      // Limpiar la ruta del mapa si es la que estaba mostrada
      if (savedRoutes.isEmpty) {
        setState(() {
          startPoint = null;
          endPoint = null;
          routePoints = [];
        });
      }
    } catch (e) {
      debugPrint('❌ Error al eliminar en Supabase: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Error al eliminar: $e")),
        );
      }
    }
  }

  // 🔹 Mostrar ruta guardada
  void _showRoute(Map<String, dynamic> route) async {
    final LatLng start = LatLng(route['lat_inicio'], route['lng_inicio']);
    final LatLng end = LatLng(route['lat_fin'], route['lng_fin']);
    setState(() {
      startPoint = start;
      endPoint = end;
      routePoints = []; // Limpiar puntos antes de obtener la nueva
      _mapController.move(start, 13.5);
    });
    await _getRouteFromAPI();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🌿 EcoRutas Nariño"),
        backgroundColor: Colors.green.shade800,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(1.214, -77.278), // Pasto
              initialZoom: 13,
              onTap: (tapPosition, point) => _handleTap(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app', // Recomendado para TileLayer
              ),
              // Capa de polilínea (Ruta)
              if (routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 5,
                      color: Colors.lightGreenAccent,
                    ),
                  ],
                ),
              // Marcadores de Inicio y Fin
              MarkerLayer(markers: [
                if (startPoint != null)
                  Marker(
                    point: startPoint!,
                    width: 45,
                    height: 45,
                    child: const Icon(Icons.location_on,
                        color: Colors.blue, size: 40),
                  ),
                if (endPoint != null)
                  Marker(
                    point: endPoint!,
                    width: 45,
                    height: 45,
                    child:
                        const Icon(Icons.flag, color: Colors.red, size: 40),
                  ),
              ]),
            ],
          ),

          // 📋 Lista de rutas guardadas (Panel)
          Positioned(
            left: 10,
            top: 10,
            child: Container(
              width: 300,
              height: 400,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))
                ],
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("📍 Rutas guardadas:",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black)),
                  const Divider(color: Colors.black38),
                  if (loading)
                    const Expanded(
                        child: Center(child: CircularProgressIndicator())),
                  if (errorMessage != null)
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(errorMessage!,
                              style: const TextStyle(color: Colors.red)),
                        ),
                      ),
                    ),
                  if (!loading && errorMessage == null)
                    Expanded(
                      child: savedRoutes.isEmpty
                          ? const Center(
                              child: Text("No hay rutas guardadas.",
                                  style: TextStyle(color: Colors.black54)))
                          : ListView.builder(
                              itemCount: savedRoutes.length,
                              itemBuilder: (context, index) {
                                final r = savedRoutes[index];
                                return Card(
                                  color: Colors.green.shade100,
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  child: ListTile(
                                    dense: true,
                                    title: Text(r['nombre'] ?? 'Sin nombre',
                                        style:
                                            const TextStyle(color: Colors.black)),
                                    subtitle: Text(r['descripcion'] ?? '',
                                        style: const TextStyle(
                                            color: Colors.black87)),
                                    leading: const Icon(Icons.map,
                                        color: Colors.green),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () => _deleteRoute(
                                          r['id'].toString()), // Eliminar
                                    ),
                                    onTap: () => _showRoute(r), // Mostrar
                                  ),
                                );
                              },
                            ),
                    ),
                ],
              ),
            ),
          ),

          // 💾 Botón flotante para Guardar
          Positioned(
            right: 15,
            bottom: 15,
            child: FloatingActionButton.extended(
              backgroundColor: Colors.green,
              onPressed: _saveRouteDialog,
              label: const Text("Guardar Ruta"),
              icon: const Icon(Icons.save),
            ),
          ),
        ],
      ),
    );
  }
}