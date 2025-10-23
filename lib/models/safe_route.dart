import 'package:latlong2/latlong.dart';

class SafeRoute {
  final String name;
  final List<LatLng> points;
  final double distanceKm;
  final String riskLevel;

  SafeRoute({
    required this.name,
    required this.points,
    required this.distanceKm,
    required this.riskLevel,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'points': points
            .map((p) => {'lat': p.latitude, 'lon': p.longitude})
            .toList(),
        'distance_km': distanceKm,
        'risk_level': riskLevel,
      };
}
