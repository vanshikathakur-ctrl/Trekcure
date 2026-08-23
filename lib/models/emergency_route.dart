import 'package:latlong2/latlong.dart';

class EmergencyResponder {
  final String id;
  final String name;
  final String type;
  final double latitude;
  final double longitude;

  const EmergencyResponder({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
  });

  factory EmergencyResponder.fromJson(Map<String, dynamic> json) {
    return EmergencyResponder(
      id: json['id'].toString(),
      name: json['name'].toString(),
      type: json['type'].toString(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  LatLng get location {
    return LatLng(latitude, longitude);
  }
}

class EmergencyRouteResult {
  final EmergencyResponder responder;
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final bool offline;

  const EmergencyRouteResult({
    required this.responder,
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.offline,
  });

  double get distanceKm {
    return distanceMeters / 1000;
  }

  int get durationMinutes {
    return (durationSeconds / 60).ceil();
  }
}
