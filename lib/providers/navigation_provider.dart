import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../models/nav_route.dart';
import '../models/obstacle.dart';
import '../services/routing_service.dart';
import 'location_provider.dart';
import 'obstacle_provider.dart';

/// The combined navigation state exposed to the UI.
class NavigationState {
  /// Creates a navigation state snapshot.
  const NavigationState({
    this.destination,
    this.destinationName,
    this.selectedPinpoint,
    this.activeRoute,
    this.isLoading = false,
    this.errorMessage,
  });

  /// The user-selected destination, or `null` if not yet set.
  final LatLng? destination;

  /// Optional display name of destination.
  final String? destinationName;

  /// Temporary pinpoint placed by single-tapping the map.
  final LatLng? selectedPinpoint;

  /// The currently computed route, or `null` if unavailable.
  final NavRoute? activeRoute;

  /// Whether a route calculation is in progress.
  final bool isLoading;

  /// An error message from the last route attempt, or `null`.
  final String? errorMessage;

  /// Creates a copy with the given fields replaced.
  NavigationState copyWith({
    LatLng? destination,
    String? destinationName,
    LatLng? selectedPinpoint,
    NavRoute? activeRoute,
    bool? isLoading,
    String? errorMessage,
    bool clearRoute = false,
    bool clearError = false,
    bool clearDestination = false,
    bool clearPinpoint = false,
  }) {
    return NavigationState(
      destination: clearDestination ? null : (destination ?? this.destination),
      destinationName: clearDestination ? null : (destinationName ?? this.destinationName),
      selectedPinpoint: clearPinpoint ? null : (selectedPinpoint ?? this.selectedPinpoint),
      activeRoute: clearRoute ? null : (activeRoute ?? this.activeRoute),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Provides the navigation state including destination, pinpoint, and active route.
final navigationProvider =
    StateNotifierProvider<NavigationNotifier, NavigationState>((ref) {
  return NavigationNotifier(ref);
});

/// Manages route calculation by combining location, destination, and obstacles.
class NavigationNotifier extends StateNotifier<NavigationState> {
  /// Creates a navigator that watches location and obstacle changes.
  NavigationNotifier(this._ref) : super(const NavigationState()) {
    // Auto-recalculate when obstacles change.
    _ref.listen<List<Obstacle>>(obstacleProvider, (_, obstacles) {
      _recalculateIfReady();
    });
  }

  final Ref _ref;
  final RoutingService _routingService = RoutingService();

  /// Default fallback start point (GECA Main Gate) if device GPS is not available.
  static const LatLng defaultCampusStart = LatLng(26.44915, 74.70310);

  /// Sets or updates the temporary pinpoint on the map.
  void setPinpoint(LatLng pinpoint) {
    state = state.copyWith(selectedPinpoint: pinpoint);
  }

  /// Clears the temporary map pinpoint.
  void clearPinpoint() {
    state = state.copyWith(clearPinpoint: true);
  }

  /// Sets the navigation destination and triggers a route calculation.
  Future<void> setDestination(LatLng destination, {String? destinationName}) async {
    state = state.copyWith(
      destination: destination,
      destinationName: destinationName,
      clearError: true,
      clearRoute: true,
      clearPinpoint: true,
    );
    await _recalculateIfReady();
  }

  /// Routes from user's current GPS location (or fallback campus location) to [destination].
  Future<void> routeFromCurrentLocationTo(
    LatLng destination, {
    String? destinationName,
  }) async {
    // If device location is unavailable, ensure start location is initialized to campus fallback
    final currentLoc = _ref.read(locationProvider);
    if (currentLoc == null) {
      _ref.read(locationProvider.notifier).setLocation(defaultCampusStart);
    }

    state = state.copyWith(
      destination: destination,
      destinationName: destinationName,
      clearError: true,
      clearRoute: true,
      clearPinpoint: true,
    );

    await _recalculateIfReady();
  }

  /// Forces a route recalculation with current state.
  Future<void> recalculateRoute() async {
    await _recalculateIfReady();
  }

  /// Clears the current destination, pinpoint, and route.
  void clearNavigation() {
    state = const NavigationState();
  }

  Future<void> _recalculateIfReady() async {
    var start = _ref.read(locationProvider);
    final destination = state.destination;

    if (destination == null) return;

    // Use default fallback if start is still null
    if (start == null) {
      start = defaultCampusStart;
      _ref.read(locationProvider.notifier).setLocation(defaultCampusStart);
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final obstacles = _ref.read(obstacleProvider);
      final route = await _routingService.fetchAccessibleRoute(
        start: start,
        destination: destination,
        obstacles: obstacles,
      );

      if (route == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              'No accessible route found. Try clearing nearby obstacles.',
          clearRoute: true,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          activeRoute: route,
          clearError: true,
        );
      }
    } on Exception catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Route error: $e',
      );
    }
  }
}
