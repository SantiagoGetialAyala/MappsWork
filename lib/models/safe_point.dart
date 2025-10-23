class SafePoint {
  final String name;
  final double latitude;
  final double longitude;
  final String type;

  SafePoint({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'type': type,
      };

  static SafePoint fromJson(Map<String, dynamic> json) => SafePoint(
        name: json['name'] ?? '',
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        type: json['type'] ?? '',
      );
}
