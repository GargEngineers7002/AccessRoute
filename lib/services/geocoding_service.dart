import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

/// Represents a searchable place suggestion.
class PlaceSuggestion {
  /// Creates a place suggestion.
  const PlaceSuggestion({
    required this.name,
    required this.subtitle,
    required this.location,
    this.isCampusPreset = false,
  });

  /// Primary name of the location.
  final String name;

  /// Secondary description or address details.
  final String subtitle;

  /// Latitude and longitude of the place.
  final LatLng location;

  /// Whether this is a local campus preset.
  final bool isCampusPreset;
}

/// Service that handles place search combining local campus presets with OSM Nominatim API.
class GeocodingService {
  /// Creates a [GeocodingService] instance.
  GeocodingService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  /// Default center coordinates of Government Engineering College, Ajmer.
  static const LatLng campusCenter = LatLng(26.4482, 74.7028);

  /// Key campus presets for Government Engineering College, Ajmer.
  static const List<PlaceSuggestion> campusPresets = [
    PlaceSuggestion(
      name: 'Library',
      subtitle: 'Government Engineering College, Ajmer',
      location: LatLng(26.44825, 74.70205),
      isCampusPreset: true,
    ),
    PlaceSuggestion(
      name: 'Old Building',
      subtitle: 'Government Engineering College, Ajmer',
      location: LatLng(26.44785, 74.70265),
      isCampusPreset: true,
    ),
    PlaceSuggestion(
      name: 'Main Gate',
      subtitle: 'Government Engineering College, Ajmer',
      location: LatLng(26.44915, 74.70310),
      isCampusPreset: true,
    ),
    PlaceSuggestion(
      name: 'Shreenagar Road Junction',
      subtitle: 'Near GECA Campus, Ajmer',
      location: LatLng(26.44925, 74.70295),
      isCampusPreset: true,
    ),
  ];

  /// Searches for places matching [query] biased toward [userLocation] or campus center.
  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    LatLng? userLocation,
  }) async {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) {
      return [];
    }

    final referenceLocation = userLocation ?? campusCenter;
    final results = <PlaceSuggestion>[];
    final seenCoords = <String>{};

    // 1. Check local campus presets first (immediate priority match)
    for (final preset in campusPresets) {
      final nameLower = preset.name.toLowerCase();
      final subtitleLower = preset.subtitle.toLowerCase();
      if (nameLower.contains(cleanQuery) || subtitleLower.contains(cleanQuery)) {
        results.add(preset);
        seenCoords.add('${preset.location.latitude.toStringAsFixed(4)},${preset.location.longitude.toStringAsFixed(4)}');
      }
    }

    // 2. Query OpenStreetMap Nominatim API
    try {
      final response = await _dio.get<List<dynamic>>(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': cleanQuery,
          'format': 'json',
          'addressdetails': '1',
          'limit': '10',
          // Viewbox biased around reference location (+/- ~0.15 deg ~16km)
          'viewbox': '${referenceLocation.longitude - 0.15},${referenceLocation.latitude + 0.15},${referenceLocation.longitude + 0.15},${referenceLocation.latitude - 0.15}',
          'bounded': '0',
        },
        options: Options(
          headers: {
            'User-Agent': 'AccessRoute-StudentProject/1.0',
            'Accept-Language': 'en',
          },
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );

      final data = response.data;
      if (data != null) {
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            final lat = double.tryParse(item['lat']?.toString() ?? '');
            final lon = double.tryParse(item['lon']?.toString() ?? '');
            if (lat == null || lon == null) continue;

            final coordKey = '${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';
            if (seenCoords.contains(coordKey)) continue;
            seenCoords.add(coordKey);

            final displayName = item['display_name'] as String? ?? '';
            final parts = displayName.split(',');
            final name = parts.isNotEmpty ? parts.first.trim() : displayName;
            final subtitle = parts.length > 1
                ? parts.skip(1).take(3).join(',').trim()
                : 'OpenStreetMap location';

            results.add(
              PlaceSuggestion(
                name: name,
                subtitle: subtitle,
                location: LatLng(lat, lon),
                isCampusPreset: false,
              ),
            );
          }
        }
      }
    } catch (_) {
      // In case of network errors or rate limit, return presets if matched
    }

    // Sort by distance to reference location
    const distanceCalc = Distance();
    results.sort((a, b) {
      // Campus presets have an inherent boost if matches are close
      final distA = distanceCalc.as(LengthUnit.Meter, referenceLocation, a.location);
      final distB = distanceCalc.as(LengthUnit.Meter, referenceLocation, b.location);

      if (a.isCampusPreset && !b.isCampusPreset) return -1;
      if (!a.isCampusPreset && b.isCampusPreset) return 1;
      return distA.compareTo(distB);
    });

    return results;
  }
}
