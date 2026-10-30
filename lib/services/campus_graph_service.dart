import 'dart:math';
import 'package:latlong2/latlong.dart';

import '../models/nav_route.dart';
import '../models/obstacle.dart';

/// Represents an edge in the local campus footpath graph.
class _GraphEdge {
  const _GraphEdge({
    required this.u,
    required this.v,
    required this.subdividedPoints,
    required this.lengthMeters,
  });

  final String u;
  final String v;
  final List<LatLng> subdividedPoints;
  final double lengthMeters;
}

/// Service providing a local footpath routing graph for the Government Engineering College campus.
class CampusGraphService {
  /// Center coordinates of the GECA campus.
  static const LatLng campusCenter = LatLng(26.4483, 74.7025);

  /// Radius in meters where campus routing is active.
  static const double campusRadiusMeters = 600.0;

  /// Obstacle avoidance buffer distance in meters.
  static const double obstacleAvoidanceRadiusMeters = 22.0;

  /// Average walking speed in meters per second (~4.5 km/h).
  static const double walkingSpeedMetersPerSec = 1.25;

  static const Distance _distanceCalc = Distance();

  /// Named nodes on the campus footpath network.
  static final Map<String, LatLng> nodes = {
    'n_shreenagar_jct': const LatLng(26.44918, 74.70305),
    'n_main_spine_north': const LatLng(26.44885, 74.70290),
    'n_upper_west_corner': const LatLng(26.44898, 74.70238),
    'n_upper_deadend': const LatLng(26.44912, 74.70172),
    'n_library_north': const LatLng(26.44845, 74.70218),
    'n_library_entrance': const LatLng(26.44822, 74.70215),
    'n_lower_path_mid': const LatLng(26.44808, 74.70245),
    'n_main_spine_mid': const LatLng(26.44835, 74.70288),
    'n_main_spine_lib_jct': const LatLng(26.44795, 74.70272),
    'n_old_building': const LatLng(26.44780, 74.70265),
    'n_main_spine_south': const LatLng(26.44730, 74.70245),
  };

  /// Raw undirected connections.
  static const List<(String, String)> _rawConnections = [
    // Main Spine
    ('n_shreenagar_jct', 'n_main_spine_north'),
    ('n_main_spine_north', 'n_main_spine_mid'),
    ('n_main_spine_mid', 'n_main_spine_lib_jct'),
    ('n_main_spine_lib_jct', 'n_old_building'),
    ('n_old_building', 'n_main_spine_south'),

    // Lower Library Path (Direct)
    ('n_main_spine_lib_jct', 'n_lower_path_mid'),
    ('n_lower_path_mid', 'n_library_entrance'),

    // Upper Library Path (Alternate Detour)
    ('n_main_spine_north', 'n_upper_west_corner'),
    ('n_upper_west_corner', 'n_library_north'),
    ('n_library_north', 'n_library_entrance'),

    // North Spur
    ('n_upper_west_corner', 'n_upper_deadend'),
  ];

  /// Precomputed edges with subdivided intermediate points (~5m).
  late final List<_GraphEdge> _edges = _buildEdges();

  List<_GraphEdge> _buildEdges() {
    final list = <_GraphEdge>[];
    for (final conn in _rawConnections) {
      final p1 = nodes[conn.$1]!;
      final p2 = nodes[conn.$2]!;
      final dist = _distanceCalc.as(LengthUnit.Meter, p1, p2);
      final numSteps = max(1, (dist / 5.0).ceil());

      final points = <LatLng>[];
      for (var i = 0; i <= numSteps; i++) {
        final t = i / numSteps;
        final lat = p1.latitude + (p2.latitude - p1.latitude) * t;
        final lng = p1.longitude + (p2.longitude - p1.longitude) * t;
        points.add(LatLng(lat, lng));
      }

      list.add(
        _GraphEdge(
          u: conn.$1,
          v: conn.$2,
          subdividedPoints: points,
          lengthMeters: dist,
        ),
      );
    }
    return list;
  }

  /// Determines if either [start] or [destination] is in the campus area.
  bool isInCampusArea(LatLng start, LatLng destination) {
    final distStart = _distanceCalc.as(LengthUnit.Meter, campusCenter, start);
    final distDest = _distanceCalc.as(LengthUnit.Meter, campusCenter, destination);
    return distStart <= campusRadiusMeters || distDest <= campusRadiusMeters;
  }

  /// Finds an accessible path on the campus graph avoiding any [obstacles].
  NavRoute? findCampusRoute(
    LatLng start,
    LatLng destination,
    List<Obstacle> obstacles,
  ) {
    final startNode = _findNearestNode(start);
    final destNode = _findNearestNode(destination);

    if (startNode == null || destNode == null) return null;

    // Build adjacency list for Dijkstra
    final adj = <String, List<_GraphEdge>>{};
    for (final k in nodes.keys) {
      adj[k] = [];
    }
    for (final edge in _edges) {
      adj[edge.u]!.add(edge);
      // reverse orientation for undirected traversal
      adj[edge.v]!.add(
        _GraphEdge(
          u: edge.v,
          v: edge.u,
          subdividedPoints: edge.subdividedPoints.reversed.toList(),
          lengthMeters: edge.lengthMeters,
        ),
      );
    }

    // Helper to check if an edge is blocked by any obstacle within 22 meters
    bool isEdgeBlocked(_GraphEdge edge) {
      for (final pt in edge.subdividedPoints) {
        for (final obs in obstacles) {
          final d = _distanceCalc.as(LengthUnit.Meter, pt, obs.position);
          if (d <= obstacleAvoidanceRadiusMeters) {
            return true;
          }
        }
      }
      return false;
    }

    // Run Dijkstra
    final distances = <String, double>{};
    final previousNode = <String, String?>{};
    final previousEdge = <String, _GraphEdge?>{};
    final unvisited = nodes.keys.toSet();

    for (final nodeKey in nodes.keys) {
      distances[nodeKey] = double.infinity;
      previousNode[nodeKey] = null;
      previousEdge[nodeKey] = null;
    }
    distances[startNode] = 0.0;

    while (unvisited.isNotEmpty) {
      // Find unvisited node with min distance
      String? current;
      var minDistance = double.infinity;
      for (final node in unvisited) {
        final d = distances[node]!;
        if (d < minDistance) {
          minDistance = d;
          current = node;
        }
      }

      if (current == null || minDistance == double.infinity) {
        break; // remaining nodes are unreachable
      }

      if (current == destNode) {
        break; // reached target
      }

      unvisited.remove(current);

      for (final edge in adj[current]!) {
        final neighbor = edge.v;
        if (!unvisited.contains(neighbor)) continue;

        if (isEdgeBlocked(edge)) continue;

        final newDist = distances[current]! + edge.lengthMeters;
        if (newDist < distances[neighbor]!) {
          distances[neighbor] = newDist;
          previousNode[neighbor] = current;
          previousEdge[neighbor] = edge;
        }
      }
    }

    if (distances[destNode] == double.infinity) {
      return null; // No accessible route found
    }

    // Reconstruct polyline path
    final routePoints = <LatLng>[start];
    final edgesOnPath = <_GraphEdge>[];

    var curr = destNode;
    while (curr != startNode) {
      final edge = previousEdge[curr];
      final prev = previousNode[curr];
      if (edge == null || prev == null) break;
      edgesOnPath.add(edge);
      curr = prev;
    }

    // Edges are gathered backwards (destNode -> startNode)
    for (final edge in edgesOnPath.reversed) {
      for (final pt in edge.subdividedPoints) {
        if (routePoints.isEmpty || routePoints.last != pt) {
          routePoints.add(pt);
        }
      }
    }

    // Append destination coordinate if not already close
    if (routePoints.isEmpty ||
        _distanceCalc.as(LengthUnit.Meter, routePoints.last, destination) > 1.0) {
      routePoints.add(destination);
    }

    // Calculate total distance along the constructed polyline
    var totalDistance = 0.0;
    for (var i = 0; i < routePoints.length - 1; i++) {
      totalDistance += _distanceCalc.as(
        LengthUnit.Meter,
        routePoints[i],
        routePoints[i + 1],
      );
    }

    final durationSeconds = totalDistance / walkingSpeedMetersPerSec;

    return NavRoute(
      points: routePoints,
      distanceMeters: totalDistance,
      durationSeconds: durationSeconds,
    );
  }

  String? _findNearestNode(LatLng point) {
    String? nearest;
    var minDistance = double.infinity;
    for (final entry in nodes.entries) {
      final d = _distanceCalc.as(LengthUnit.Meter, point, entry.value);
      if (d < minDistance) {
        minDistance = d;
        nearest = entry.key;
      }
    }
    return nearest;
  }
}
