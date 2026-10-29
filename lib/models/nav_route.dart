import 'package:latlong2/latlong.dart';

/// Represents a computed navigation route.
class NavRoute {
  /// Creates a navigation route from decoded API response data.
  const NavRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  /// Ordered list of geographic coordinates forming the route polyline.
  final List<LatLng> points;

  /// Total route distance in meters.
  final double distanceMeters;

  /// Estimated travel duration in seconds.
  final double durationSeconds;

  /// Formats [durationSeconds] as a human-readable string (e.g. "12 min").
  String get formattedDuration {
    final minutes = (durationSeconds / 60).ceil();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}m';
  }

  /// Formats [distanceMeters] as a human-readable string.
  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }
}
