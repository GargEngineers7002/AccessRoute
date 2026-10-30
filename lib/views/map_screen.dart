import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../models/obstacle.dart';
import '../providers/location_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/obstacle_provider.dart';
import '../services/geocoding_service.dart';
import 'widgets/add_obstacle_dialog.dart';
import 'widgets/pinpoint_action_card.dart';
import 'widgets/place_search_bar.dart';
import 'widgets/route_info_banner.dart';

/// The primary map screen displaying tiles, obstacles, and the active route.
class MapScreen extends ConsumerStatefulWidget {
  /// Creates the map screen.
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController = MapController();

  /// Default center: Government Engineering College, Ajmer.
  static const _defaultCenter = LatLng(26.4482, 74.7028);

  @override
  void initState() {
    super.initState();
    // Attempt to get user location on startup.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLocation();
    });
  }

  Future<void> _initLocation() async {
    final error =
        await ref.read(locationProvider.notifier).fetchCurrentLocation();
    if (error != null && mounted) {
      // In case GPS is denied or unavailable, set to college campus center
      ref.read(locationProvider.notifier).setLocation(_defaultCenter);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location note: $error. Defaulted to Campus.'),
          duration: const Duration(seconds: 3),
        ),
      );
      _mapController.move(_defaultCenter, 16);
    } else {
      final location = ref.read(locationProvider);
      if (location != null) {
        _mapController.move(location, 16);
      }
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Single tap on map: places or moves temporary pinpoint
  void _onMapTap(TapPosition tapPosition, LatLng position) {
    ref.read(navigationProvider.notifier).setPinpoint(position);
  }

  /// Long press on map: opens Add Obstacle dialog
  void _onLongPress(TapPosition tapPosition, LatLng position) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddObstacleDialog(position: position),
    );
  }

  void _onPlaceSelected(PlaceSuggestion place) {
    ref.read(navigationProvider.notifier).routeFromCurrentLocationTo(
          place.location,
          destinationName: place.name,
        );

    final userLoc = ref.read(locationProvider) ?? _defaultCenter;
    _fitPointsToMap([userLoc, place.location]);
  }

  void _routeToPinpoint(LatLng pinpoint) {
    ref.read(navigationProvider.notifier).routeFromCurrentLocationTo(
          pinpoint,
          destinationName: 'Custom Pinpoint',
        );

    final userLoc = ref.read(locationProvider) ?? _defaultCenter;
    _fitPointsToMap([userLoc, pinpoint]);
  }

  void _fitPointsToMap(List<LatLng> points) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.first, 16);
      return;
    }

    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.only(
          top: 100,
          bottom: 120,
          left: 40,
          right: 40,
        ),
      ),
    );
  }

  IconData _obstacleIcon(ObstacleType type) {
    return switch (type) {
      ObstacleType.stairs => Icons.stairs,
      ObstacleType.brokenElevator => Icons.elevator,
      ObstacleType.construction => Icons.construction,
      ObstacleType.narrowPath => Icons.compress,
      ObstacleType.steepSlope => Icons.landscape,
    };
  }

  @override
  Widget build(BuildContext context) {
    final userLocation = ref.watch(locationProvider);
    final navState = ref.watch(navigationProvider);
    final obstacles = ref.watch(obstacleProvider);

    // Listen for navigation errors and show SnackBars.
    ref.listen<NavigationState>(navigationProvider, (prev, next) {
      if (next.errorMessage != null && prev?.errorMessage != next.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: const Color(0xFFD32F2F),
            action: SnackBarAction(
              label: 'Clear obstacles',
              textColor: Colors.white,
              onPressed: () {
                ref.read(obstacleProvider.notifier).clearAll();
                ref.read(navigationProvider.notifier).recalculateRoute();
              },
            ),
          ),
        );
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: userLocation ?? _defaultCenter,
              initialZoom: 16.0,
              minZoom: 3.0,
              maxZoom: 18.0,
              onTap: _onMapTap,
              onLongPress: _onLongPress,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              // Layer 1: OSM Tiles (cache-busted to fetch newly mapped college buildings)
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png?v=2',
                userAgentPackageName: 'com.accessroute.access_route',
                maxZoom: 19,
                tileProvider: CancellableNetworkTileProvider(),
              ),

              // Layer 2: Route polyline
              if (navState.activeRoute != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: navState.activeRoute!.points,
                      strokeWidth: 5.5,
                      color: const Color(0xFF42A5F5),
                      borderStrokeWidth: 2.0,
                      borderColor: const Color(0xFF1565C0),
                    ),
                  ],
                ),

              // Layer 3: Markers
              MarkerLayer(
                markers: [
                  // User location marker
                  if (userLocation != null)
                    Marker(
                      point: userLocation,
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withAlpha(51),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF4CAF50),
                            width: 2.5,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.my_location,
                            color: Color(0xFF4CAF50),
                            size: 22,
                          ),
                        ),
                      ),
                    ),

                  // Destination marker
                  if (navState.destination != null)
                    Marker(
                      point: navState.destination!,
                      width: 44,
                      height: 44,
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.location_on,
                        color: Color(0xFFEF5350),
                        size: 44,
                      ),
                    ),

                  // Temporary Single-Tap Pinpoint marker
                  if (navState.selectedPinpoint != null)
                    Marker(
                      point: navState.selectedPinpoint!,
                      width: 42,
                      height: 42,
                      alignment: Alignment.topCenter,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFAB47BC).withAlpha(140),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.place_rounded,
                          color: Color(0xFFBA68C8),
                          size: 42,
                        ),
                      ),
                    ),

                  // Obstacle markers
                  ...obstacles.map((obstacle) {
                    return Marker(
                      point: obstacle.position,
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      child: GestureDetector(
                        onTap: () => _showObstacleInfo(obstacle),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE65100).withAlpha(204),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              _obstacleIcon(obstacle.type),
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),

              // Attribution
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),

          // ── Autocomplete Place Search Bar (top) ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: PlaceSearchBar(
                userLocation: userLocation,
                currentDestinationName: navState.destinationName,
                onPlaceSelected: _onPlaceSelected,
                onClear: () {
                  ref.read(navigationProvider.notifier).clearNavigation();
                },
              ),
            ),
          ),

          // ── Pinpoint Action Card (floating above bottom when pinpoint is set) ──
          if (navState.selectedPinpoint != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: navState.activeRoute != null ? 95 : 20,
              child: SafeArea(
                child: PinpointActionCard(
                  pinpoint: navState.selectedPinpoint!,
                  onRouteHere: () => _routeToPinpoint(navState.selectedPinpoint!),
                  onDismiss: () {
                    ref.read(navigationProvider.notifier).clearPinpoint();
                  },
                ),
              ),
            ),

          // ── Route info banner (bottom) ──
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: RouteInfoBanner(),
            ),
          ),

          // ── Loading overlay ──
          if (navState.isLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33000000),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),

      // ── My location FAB ──
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: navState.activeRoute != null
              ? (navState.selectedPinpoint != null ? 170 : 100)
              : (navState.selectedPinpoint != null ? 90 : 16),
        ),
        child: FloatingActionButton.small(
          onPressed: _initLocation,
          backgroundColor: const Color(0xFF1B2838),
          child: const Icon(Icons.my_location, color: Color(0xFF4FC3F7)),
        ),
      ),
    );
  }

  void _showObstacleInfo(Obstacle obstacle) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE65100).withAlpha(51),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _obstacleIcon(obstacle.type),
                    color: const Color(0xFFE65100),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        obstacle.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        obstacle.type.label,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Reported: ${_formatTime(obstacle.reportedAt)}',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  ref
                      .read(obstacleProvider.notifier)
                      .removeObstacle(obstacle.id);
                  ref
                      .read(navigationProvider.notifier)
                      .recalculateRoute();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Remove Obstacle'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF5350),
                  side: const BorderSide(color: Color(0xFFEF5350)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hour(s) ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
