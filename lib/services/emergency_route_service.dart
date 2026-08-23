import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/emergency_route.dart';
import 'trekcure_api_service.dart';

class EmergencyRouteService {
  EmergencyRouteService._();

  static final EmergencyRouteService instance = EmergencyRouteService._();

  // ============================================================
  // ONLINE ROUTING
  // ============================================================

  Future<EmergencyRouteResult> findOnlineRoute({
    required double victimLatitude,
    required double victimLongitude,
  }) async {
    final uri = Uri.parse(
      '${TrekCureApiService.baseUrl}/route'
      '?latitude=$victimLatitude'
      '&longitude=$victimLongitude',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Online routing failed: ${response.body}');
    }

    final Map<String, dynamic> data = Map<String, dynamic>.from(
      jsonDecode(response.body),
    );

    final Map<String, dynamic> responderData = Map<String, dynamic>.from(
      data['responder'],
    );

    final EmergencyResponder responder = EmergencyResponder.fromJson(
      responderData,
    );

    final Map<String, dynamic> routeData = Map<String, dynamic>.from(
      data['route'],
    );

    final List<dynamic> coordinates = routeData['coordinates'] ?? [];

    final List<LatLng> points = [];

    for (final coordinate in coordinates) {
      final List<dynamic> pair = List<dynamic>.from(coordinate);

      if (pair.length < 2) {
        continue;
      }

      // GeoJSON format:
      // [longitude, latitude]
      points.add(
        LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble()),
      );
    }

    return EmergencyRouteResult(
      responder: responder,
      points: points,
      distanceMeters: (routeData['distance'] as num).toDouble(),
      durationSeconds: (routeData['duration'] as num).toDouble(),
      offline: false,
    );
  }

  // ============================================================
  // OFFLINE ROUTING
  // ============================================================

  Future<EmergencyRouteResult> findOfflineRoute({
    required double victimLatitude,
    required double victimLongitude,
  }) async {
    final String rawData = await rootBundle.loadString(
      'asset/data/offline_routes.json',
    );

    final Map<String, dynamic> data = Map<String, dynamic>.from(
      jsonDecode(rawData),
    );

    // ----------------------------------------------------------
    // LOAD NODES
    // ----------------------------------------------------------

    final List<dynamic> nodeData = data['nodes'] ?? [];

    final Map<String, OfflineNode> nodes = {};

    for (final item in nodeData) {
      final Map<String, dynamic> json = Map<String, dynamic>.from(item);

      final OfflineNode node = OfflineNode.fromJson(json);

      nodes[node.id] = node;
    }

    // ----------------------------------------------------------
    // LOAD RESPONDERS
    // ----------------------------------------------------------

    final List<dynamic> responderData = data['responders'] ?? [];

    final List<OfflineResponder> responders = [];

    for (final item in responderData) {
      responders.add(
        OfflineResponder.fromJson(Map<String, dynamic>.from(item)),
      );
    }

    if (nodes.isEmpty) {
      throw Exception('Offline route data contains no nodes.');
    }

    if (responders.isEmpty) {
      throw Exception('Offline route data contains no responders.');
    }

    // ----------------------------------------------------------
    // FIND NEAREST NODE TO VICTIM
    // ----------------------------------------------------------

    final String victimNodeId = _nearestNodeId(
      nodes,
      victimLatitude,
      victimLongitude,
    );

    // ----------------------------------------------------------
    // CALCULATE ROUTE FROM EVERY RESPONDER
    // ----------------------------------------------------------

    OfflineRouteCandidate? bestCandidate;

    for (final responder in responders) {
      if (!nodes.containsKey(responder.nodeId)) {
        continue;
      }

      final List<String>? path = _aStar(
        nodes: nodes,
        startId: responder.nodeId,
        goalId: victimNodeId,
      );

      if (path == null || path.isEmpty) {
        continue;
      }

      final List<LatLng> points = [];

      double totalDistance = 0;

      for (int i = 0; i < path.length; i++) {
        final OfflineNode node = nodes[path[i]]!;

        points.add(LatLng(node.latitude, node.longitude));

        if (i > 0) {
          final OfflineNode previous = nodes[path[i - 1]]!;

          totalDistance += _distanceMeters(
            previous.latitude,
            previous.longitude,
            node.latitude,
            node.longitude,
          );
        }
      }

      // Approximate walking speed:
      // 1.4 m/s ≈ 5 km/h
      const double speedMetersPerSecond = 1.4;

      final double duration = totalDistance / speedMetersPerSecond;

      final candidate = OfflineRouteCandidate(
        responder: responder,
        path: path,
        distanceMeters: totalDistance,
        durationSeconds: duration,
        points: points,
      );

      // Select fastest responder
      if (bestCandidate == null ||
          candidate.durationSeconds < bestCandidate.durationSeconds) {
        bestCandidate = candidate;
      }
    }

    if (bestCandidate == null) {
      throw Exception('No offline route could be found.');
    }

    final EmergencyResponder responder = EmergencyResponder(
      id: bestCandidate.responder.id,
      name: bestCandidate.responder.name,
      type: bestCandidate.responder.type,
      latitude: bestCandidate.responder.latitude,
      longitude: bestCandidate.responder.longitude,
    );

    return EmergencyRouteResult(
      responder: responder,
      points: bestCandidate.points,
      distanceMeters: bestCandidate.distanceMeters,
      durationSeconds: bestCandidate.durationSeconds,
      offline: true,
    );
  }

  // ============================================================
  // A* ALGORITHM
  // ============================================================

  List<String>? _aStar({
    required Map<String, OfflineNode> nodes,
    required String startId,
    required String goalId,
  }) {
    final Map<String, double> gScore = {};
    final Map<String, double> fScore = {};
    final Map<String, String> cameFrom = {};

    final List<String> openSet = [];

    for (final id in nodes.keys) {
      gScore[id] = double.infinity;
      fScore[id] = double.infinity;
    }

    gScore[startId] = 0;

    fScore[startId] = _heuristic(nodes[startId]!, nodes[goalId]!);

    openSet.add(startId);

    while (openSet.isNotEmpty) {
      openSet.sort((a, b) {
        return fScore[a]!.compareTo(fScore[b]!);
      });

      final String current = openSet.removeAt(0);

      if (current == goalId) {
        return _reconstructPath(cameFrom, current);
      }

      final OfflineNode currentNode = nodes[current]!;

      for (final neighborId in currentNode.neighbors) {
        if (!nodes.containsKey(neighborId)) {
          continue;
        }

        final OfflineNode neighbor = nodes[neighborId]!;

        final double edgeDistance = _distanceMeters(
          currentNode.latitude,
          currentNode.longitude,
          neighbor.latitude,
          neighbor.longitude,
        );

        final double tentativeG = gScore[current]! + edgeDistance;

        if (tentativeG < gScore[neighborId]!) {
          cameFrom[neighborId] = current;

          gScore[neighborId] = tentativeG;

          fScore[neighborId] =
              tentativeG + _heuristic(neighbor, nodes[goalId]!);

          if (!openSet.contains(neighborId)) {
            openSet.add(neighborId);
          }
        }
      }
    }

    return null;
  }

  // ============================================================
  // RECONSTRUCT A* PATH
  // ============================================================

  List<String> _reconstructPath(Map<String, String> cameFrom, String current) {
    final List<String> path = [current];

    while (cameFrom.containsKey(current)) {
      current = cameFrom[current]!;
      path.add(current);
    }

    return path.reversed.toList();
  }

  // ============================================================
  // A* HEURISTIC
  // ============================================================

  double _heuristic(OfflineNode a, OfflineNode b) {
    return _distanceMeters(a.latitude, a.longitude, b.latitude, b.longitude);
  }

  // ============================================================
  // FIND NEAREST OFFLINE NODE
  // ============================================================

  String _nearestNodeId(
    Map<String, OfflineNode> nodes,
    double latitude,
    double longitude,
  ) {
    String? closestId;

    double closestDistance = double.infinity;

    for (final node in nodes.values) {
      final double distance = _distanceMeters(
        latitude,
        longitude,
        node.latitude,
        node.longitude,
      );

      if (distance < closestDistance) {
        closestDistance = distance;
        closestId = node.id;
      }
    }

    if (closestId == null) {
      throw Exception('No offline map node is available.');
    }

    return closestId;
  }

  // ============================================================
  // HAVERSINE DISTANCE
  // ============================================================

  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000;

    final double dLat = _radians(lat2 - lat1);

    final double dLon = _radians(lon2 - lon1);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_radians(lat1)) *
            cos(_radians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _radians(double degrees) {
    return degrees * pi / 180;
  }
}

// ============================================================
// OFFLINE NODE
// ============================================================

class OfflineNode {
  final String id;
  final double latitude;
  final double longitude;
  final List<String> neighbors;

  const OfflineNode({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.neighbors,
  });

  factory OfflineNode.fromJson(Map<String, dynamic> json) {
    return OfflineNode(
      id: json['id'].toString(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      neighbors: List<String>.from(json['neighbors'] ?? []),
    );
  }
}

// ============================================================
// OFFLINE RESPONDER
// ============================================================

class OfflineResponder {
  final String id;
  final String name;
  final String type;
  final String nodeId;
  final double latitude;
  final double longitude;

  const OfflineResponder({
    required this.id,
    required this.name,
    required this.type,
    required this.nodeId,
    required this.latitude,
    required this.longitude,
  });

  factory OfflineResponder.fromJson(Map<String, dynamic> json) {
    return OfflineResponder(
      id: json['id'].toString(),
      name: json['name'].toString(),
      type: json['type'].toString(),
      nodeId: json['nodeId'].toString(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

// ============================================================
// OFFLINE ROUTE CANDIDATE
// ============================================================

class OfflineRouteCandidate {
  final OfflineResponder responder;
  final List<String> path;
  final double distanceMeters;
  final double durationSeconds;
  final List<LatLng> points;

  const OfflineRouteCandidate({
    required this.responder,
    required this.path,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.points,
  });
}
