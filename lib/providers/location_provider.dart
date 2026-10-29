import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../services/location_service.dart';

/// Provides the current user GPS position, or `null` if unavailable.
final locationProvider =
    StateNotifierProvider<LocationNotifier, LatLng?>((ref) {
  return LocationNotifier();
});

/// Manages the user's current GPS location.
class LocationNotifier extends StateNotifier<LatLng?> {
  /// Starts with no known position.
  LocationNotifier() : super(null);

  /// Attempts to fetch the current device location.
  ///
  /// On success, updates [state] with the new position.
  /// On failure, returns the error message for UI display.
  Future<String?> fetchCurrentLocation() async {
    try {
      final position = await LocationService.determinePosition();
      state = LatLng(position.latitude, position.longitude);
      return null;
    } on Exception catch (e) {
      return e.toString();
    }
  }

  /// Manually sets the user's location (e.g. from a text input).
  void setLocation(LatLng location) {
    state = location;
  }
}
