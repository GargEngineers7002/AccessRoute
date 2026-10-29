import 'dart:math';

import 'package:latlong2/latlong.dart';

/// Types of accessibility obstacles that can be reported.
enum ObstacleType {
  stairs('Stairs', '🚫'),
  brokenElevator('Broken Elevator', '🔧'),
  construction('Construction', '🚧'),
  narrowPath('Narrow Path', '↔️'),
  steepSlope('Steep Slope', '⛰️');

  const ObstacleType(this.label, this.emoji);

  /// Human-readable label for this obstacle type.
  final String label;

  /// Emoji icon representing this obstacle type.
  final String emoji;
}

/// Represents a reported accessibility obstacle at a geographic location.
class Obstacle {
  /// Creates an obstacle with the given properties.
  const Obstacle({
    required this.id,
    required this.position,
    required this.title,
    required this.type,
    required this.reportedAt,
  });

  /// Unique identifier for this obstacle.
  final String id;

  /// Geographic coordinates of this obstacle.
  final LatLng position;

  /// User-provided description of the obstacle.
  final String title;

  /// Category of this obstacle.
  final ObstacleType type;

  /// When this obstacle was reported.
  final DateTime reportedAt;

  /// Generates a closed clockwise bounding polygon around this obstacle.
  ///
  /// Returns a list of `[longitude, latitude]` coordinate pairs forming
  /// a rectangular exclusion zone. The polygon is closed (first point
  /// repeated at end) and follows the right-hand rule (clockwise winding)
  /// as required by the OpenRouteService `avoid_polygons` payload.
  List<List<double>> toBoundingPolygon(double radiusInMeters) {
    // Convert radius to approximate degrees.
    // 1 degree latitude ≈ 111,320 meters.
    final latOffset = radiusInMeters / 111320.0;
    // Longitude degrees vary by latitude.
    final lngOffset =
        radiusInMeters / (111320.0 * cos(position.latitude * pi / 180.0));

    final south = position.latitude - latOffset;
    final north = position.latitude + latOffset;
    final west = position.longitude - lngOffset;
    final east = position.longitude + lngOffset;

    // Clockwise winding: SW → NW → NE → SE → SW (closed).
    return [
      [west, south],
      [west, north],
      [east, north],
      [east, south],
      [west, south],
    ];
  }
}
