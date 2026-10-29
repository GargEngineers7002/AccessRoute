import 'package:geolocator/geolocator.dart';

/// Wraps the [Geolocator] plugin to handle permission flow and position retrieval.
class LocationService {
  /// Determines the current device position.
  ///
  /// Checks that location services are enabled and that the app has
  /// permission, requesting it if necessary. Throws descriptive exceptions
  /// on failure so callers can display appropriate UI feedback.
  static Future<Position> determinePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission was denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permissions are permanently denied. '
        'Please enable them in app settings.',
      );
    }

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
      timeLimit: Duration(seconds: 15),
    );

    return Geolocator.getCurrentPosition(
      locationSettings: locationSettings,
    );
  }
}
