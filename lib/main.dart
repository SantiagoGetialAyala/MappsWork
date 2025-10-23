import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Constante para el nombre de la tabla.
const String _kTableName = 'rutas_ecologicas';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización de Supabase con tu URL y Anon Key
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
        // Colores sutiles en el tema oscuro
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green.shade600,
          brightness: Brightness.dark,
          primary: Colors.green.shade400,
        ),
        scaffoldBackgroundColor: Colors.grey.shade900,
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}

// === MapScreen y su lógica ===

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
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadSavedRoutes();
  }

  // 🔹 Cargar rutas guardadas
  Future<void> loadSavedRoutes() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });
    try {
      final data = await supabase
          .from(_kTableName)
          .select()
          .order('created_at', ascending: false);

      setState(() {
        savedRoutes = List<Map<String, dynamic>>.from(data);
        loading = false;
      });
    } on PostgrestException catch (e) {
      debugPrint('⚠️ Error al cargar rutas (Postgrest): $e');
      setState(() {
        errorMessage =
            'Error: ${e.message}. Verifica que la tabla "$_kTableName" exista y los permisos.';
        loading = false;
      });
    } catch (e) {
      debugPrint('⚠️ Error al cargar rutas: $e');
      setState(() {
        errorMessage = 'Error desconocido al cargar rutas.';
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
      final coords = data['routes'][0]['geometry']['coordinates'] as List;
      setState(() {
        routePoints = coords
            .map((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
            .toList();
      });
    } else {
      debugPrint('❌ Error al obtener ruta de OSRM: ${response.statusCode}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Error al calcular la ruta (OSRM)")),
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
        backgroundColor: Theme.of(context).cardColor,
        title: const Text("💾 Guardar Nueva Ruta",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: "Nombre de la ruta",
                labelStyle: const TextStyle(color: Colors.white70),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: InputDecoration(
                labelText: "Descripción",
                labelStyle: const TextStyle(color: Colors.white70),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
            ),
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
            icon: const Icon(Icons.save),
            label: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  // 🔹 Eliminar una ruta (Lógica mejorada)
  Future<void> _deleteRoute(String routeId) async {
    try {
      // 1. Obtener la ruta antes de eliminarla, si existe.
      final routeToDelete = savedRoutes.firstWhere(
        (r) => r['id'].toString() == routeId,
        orElse: () => <String, dynamic>{},
      );

      // 2. Eliminar de Supabase.
      await supabase.from(_kTableName).delete().eq('id', routeId);
      
      // 3. Recargar la lista de rutas guardadas.
      await loadSavedRoutes(); 

      // 4. Lógica de limpieza visual (Instantánea):
      // Si la ruta eliminada coincide con la ruta que se muestra en el mapa, la borramos.
      if (startPoint != null && endPoint != null && routeToDelete.isNotEmpty) {
          if (routeToDelete['lat_inicio'] == startPoint!.latitude &&
              routeToDelete['lng_inicio'] == startPoint!.longitude &&
              routeToDelete['lat_fin'] == endPoint!.latitude &&
              routeToDelete['lng_fin'] == endPoint!.longitude) {

            // Limpiamos los puntos del mapa.
            setState(() {
              startPoint = null;
              endPoint = null;
              routePoints = [];
            });
          }
      } else if (savedRoutes.isEmpty) {
          // Si después de eliminar no queda ninguna ruta, limpiamos el mapa por si acaso.
          setState(() {
            startPoint = null;
            endPoint = null;
            routePoints = [];
          });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🗑️ Ruta eliminada correctamente")),
        );
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
      routePoints = [];
      // Ajustar el zoom para que la ruta quepa o se centre de forma elegante.
      _mapController.move(LatLngBounds(start, end).center, 13);
    });
    await _getRouteFromAPI();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🌿 EcoRutas Nariño",
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.green.shade800,
        centerTitle: true,
        elevation: 4,
      ),
      body: Stack(
        children: [
          // 🗺️ Capa de Mapa y Ruta
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(1.214, -77.278), // Pasto
              initialZoom: 13,
              minZoom: 2,
              maxZoom: 18,
              onTap: (tapPosition, point) => _handleTap(point),
            ),
            children: [
              // Usamos un TileLayer con tema oscuro para un aspecto profesional
              TileLayer(
                urlTemplate:
                    'https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}{r}.png',
                userAgentPackageName: 'com.ecorutas.app',
                additionalOptions: const {
                  'accessToken': '',
                  'id': 'stamen.toner',
                },
              ),
              // Capa de polilínea (Ruta) - Color vibrante
              if (routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 6,
                      color: Colors.cyanAccent.shade400, // Color moderno y visible
                    ),
                  ],
                ),
              // Marcadores de Inicio y Fin - Estilo profesional
              MarkerLayer(markers: [
                if (startPoint != null)
                  Marker(
                    point: startPoint!,
                    width: 40,
                    height: 40,
                    child: Icon(Icons.location_on_rounded,
                        color: Colors.blue.shade300, size: 40),
                  ),
                if (endPoint != null)
                  Marker(
                    point: endPoint!,
                    width: 40,
                    height: 40,
                    child: Icon(Icons.flag_circle_rounded,
                        color: Colors.red.shade400, size: 40),
                  ),
              ]),
            ],
          ),

          // 📋 Panel de Rutas Guardadas (Posicionado Arriba a la Izquierda)
          Positioned(
            left: 10,
            top: 10,
            child: Container(
              width: 300,
              height: 400,
              decoration: BoxDecoration(
                // Usamos el color del Card con una ligera opacidad para contraste
                color: Theme.of(context).cardColor.withOpacity(0.95),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black45, blurRadius: 10, offset: Offset(0, 2))
                ],
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0, top: 4.0, bottom: 4.0),
                    child: Text("📍 Rutas Guardadas:",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.white)),
                  ),
                  const Divider(height: 1, color: Colors.white24),
                  
                  // Contenido de la lista
                  Expanded(
                    child: _buildRouteList(),
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
              backgroundColor: Colors.green.shade600,
              onPressed: _saveRouteDialog,
              label: const Text("Guardar Ruta",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              icon: const Icon(Icons.save, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Widget separado para construir la lista de rutas
  Widget _buildRouteList() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade400, fontSize: 14)),
        ),
      );
    }
    if (savedRoutes.isEmpty) {
      return const Center(
          child: Text("No hay rutas guardadas.\nSelecciona dos puntos y guarda.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54)));
    }

    return ListView.builder(
      itemCount: savedRoutes.length,
      itemBuilder: (context, index) {
        final r = savedRoutes[index];
        return Card(
          color: Colors.white12, // Color de fondo sutil para la tarjeta
          elevation: 0,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: ListTile(
            contentPadding: const EdgeInsets.only(left: 12, right: 8),
            dense: true,
            leading: Icon(Icons.timeline, color: Colors.green.shade400, size: 24),
            title: Text(r['nombre'] ?? 'Ruta Desconocida',
                style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white)),
            subtitle: Text(r['descripcion'] ?? 'Sin descripción.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility, color: Colors.blueAccent, size: 20),
                  tooltip: 'Ver en mapa',
                  onPressed: () => _showRoute(r),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  tooltip: 'Eliminar ruta',
                  onPressed: () => _deleteRoute(r['id'].toString()),
                ),
              ],
            ),
            onTap: () => _showRoute(r),
          ),
        );
      },
    );
  }
}