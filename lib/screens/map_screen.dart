import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/supabase_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final MapController _mapController = MapController();

  LatLng? startPoint;
  LatLng? endPoint;
  List<LatLng> routePoints = [];
  List<Map<String, dynamic>> savedRoutes = [];

  @override
  void initState() {
    super.initState();
    loadSavedRoutes();
  }

  Future<void> loadSavedRoutes() async {
    final data = await _supabaseService.getRoutes();
    setState(() {
      savedRoutes = data;
    });
  }

  void _handleTap(LatLng point) {
    setState(() {
      if (startPoint == null) {
        startPoint = point;
      } else if (endPoint == null) {
        endPoint = point;
        routePoints = [startPoint!, endPoint!];
      } else {
        startPoint = point;
        endPoint = null;
        routePoints = [];
      }
    });
  }

  Future<void> _saveRouteDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    if (startPoint == null || endPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Selecciona dos puntos antes de guardar.")),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Guardar Ruta"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameController,
                decoration:
                    const InputDecoration(labelText: "Nombre de la ruta")),
            TextField(
                controller: descController,
                decoration:
                    const InputDecoration(labelText: "Descripción")),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (nameController.text.isEmpty ||
                  descController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Completa todos los campos.")));
                return;
              }
              await _supabaseService.saveRoute(
                name: nameController.text,
                description: descController.text,
                latStart: startPoint!.latitude,
                lngStart: startPoint!.longitude,
                latEnd: endPoint!.latitude,
                lngEnd: endPoint!.longitude,
              );
              Navigator.pop(ctx);
              loadSavedRoutes();
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("EcoRutas Urbanas"),
        backgroundColor: Colors.green.shade700,
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
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              ),
              if (routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 5,
                      color: Colors.green,
                    ),
                  ],
                ),
              if (startPoint != null)
                MarkerLayer(markers: [
                  Marker(
                    point: startPoint!,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_on,
                        color: Colors.blue, size: 36),
                  ),
                ]),
              if (endPoint != null)
                MarkerLayer(markers: [
                  Marker(
                    point: endPoint!,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.flag,
                        color: Colors.red, size: 36),
                  ),
                ]),
            ],
          ),
          Positioned(
            right: 15,
            bottom: 15,
            child: FloatingActionButton.extended(
              backgroundColor: Colors.green,
              onPressed: _saveRouteDialog,
              label: const Text("Guardar"),
              icon: const Icon(Icons.save),
            ),
          ),
          Positioned(
            left: 10,
            top: 80,
            child: Container(
              width: 230,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("📍 Rutas guardadas:",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    ...savedRoutes.map(
                      (r) => Card(
                        elevation: 2,
                        child: ListTile(
                          dense: true,
                          title: Text(r['nombre']),
                          subtitle: Text(r['descripcion']),
                          onTap: () {
                            _mapController.move(
                              LatLng(r['lat_inicio'], r['lng_inicio']),
                              14,
                            );
                            setState(() {
                              startPoint =
                                  LatLng(r['lat_inicio'], r['lng_inicio']);
                              endPoint =
                                  LatLng(r['lat_fin'], r['lng_fin']);
                              routePoints = [startPoint!, endPoint!];
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
