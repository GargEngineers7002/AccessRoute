import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:latlong2/latlong.dart';

import '../models/nav_route.dart';
import '../models/obstacle.dart';

/// Communicates with the OpenRouteService Directions API.
class RoutingService {
  /// Creates a [RoutingService] with a pre-configured [Dio] client.
  RoutingService() : _dio = Dio();

  final Dio _dio;

  static const _baseUrl =
      'https://api.openrouteservice.org/v2/directions/foot-walking/geojson';

  /// Fetches an accessible walking route that avoids all [obstacles].
  ///
  /// Sends a POST request to the ORS foot-walking endpoint with
  /// dynamically generated `avoid_polygons` built from the active
  /// obstacle list. Returns a [NavRoute] on success, or `null` if
  /// no accessible route can be found (HTTP 404).
  Future<NavRoute?> fetchAccessibleRoute({
    required LatLng start,
    required LatLng destination,
    required List<Obstacle> obstacles,
  }) async {
    final apiKey = dotenv.env['ORS_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('ORS_API_KEY not found in .env file.');
    }

    final body = <String, dynamic>{
      'coordinates': [
        [start.longitude, start.latitude],
        [destination.longitude, destination.latitude],
      ],
      'elevation': false,
      'instructions': true,
      'language': 'en',
      'units': 'm',
    };

    // Build avoid_polygons from active obstacles.
    if (obstacles.isNotEmpty) {
      final polygonCoordinates = obstacles
          .map((o) => o.toBoundingPolygon(30)) // 30 m exclusion radius
          .toList();

      if (polygonCoordinates.length == 1) {
        body['options'] = {
          'avoid_polygons': {
            'type': 'Polygon',
            'coordinates': polygonCoordinates,
          },
        };
      } else {
        body['options'] = {
          'avoid_polygons': {
            'type': 'MultiPolygon',
            'coordinates':
                polygonCoordinates.map((ring) => [ring]).toList(),
          },
        };
      }
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _baseUrl,
        data: body,
        options: Options(
          headers: {
            'Authorization': apiKey,
            'Content-Type': 'application/json; charset=utf-8',
            'Accept':
                'application/geo+json, application/json; charset=utf-8',
          },
        ),
      );

      return _parseGeoJsonResponse(response.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null; // No route found
      }
      rethrow;
    }
  }

  /// Parses a GeoJSON FeatureCollection response into a [NavRoute].
  NavRoute _parseGeoJsonResponse(Map<String, dynamic> json) {
    final features = json['features'] as List<dynamic>;
    if (features.isEmpty) {
      throw Exception('Empty features array in ORS response.');
    }

    final feature = features[0] as Map<String, dynamic>;
    final geometry = feature['geometry'] as Map<String, dynamic>;
    final coordinates = geometry['coordinates'] as List<dynamic>;
    final properties = feature['properties'] as Map<String, dynamic>;
    final summary = properties['summary'] as Map<String, dynamic>;

    final points = coordinates.map<LatLng>((coord) {
      final c = coord as List<dynamic>;
      return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
    }).toList();

    return NavRoute(
      points: points,
      distanceMeters: (summary['distance'] as num).toDouble(),
      durationSeconds: (summary['duration'] as num).toDouble(),
    );
  }
}
