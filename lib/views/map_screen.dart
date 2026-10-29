import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../models/obstacle.dart';
import '../providers/location_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/obstacle_provider.dart';
import 'widgets/add_obstacle_dialog.dart';
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
  final _startController = TextEditingController();
  final _destController = TextEditingController();
  bool _searchBarExpanded = false;

  /// Default center: Heidelberg, Germany.
  static const _defaultCenter = LatLng(49.4094, 8.6940);

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location unavailable: $error'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _initLocation,
          ),
        ),
      );
    } else {
      final location = ref.read(locationProvider);
      if (location != null) {
        _mapController.move(location, 15);
      }
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    _startController.dispose();
    _destController.dispose();
    super.dispose();
  }

  void _onLongPress(TapPosition tapPosition, LatLng position) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddObstacleDialog(position: position),
    );
  }

  void _handleSearch() {
    final startParts = _startController.text.trim().split(',');
    final destParts = _destController.text.trim().split(',');

    if (startParts.length != 2 || destParts.length != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter coordinates as "lat, lng" for both fields.'),
        ),
      );
      return;
    }

    try {
      final startLat = double.parse(startParts[0].trim());
      final startLng = double.parse(startParts[1].trim());
      final destLat = double.parse(destParts[0].trim());
      final destLng = double.parse(destParts[1].trim());

      ref
          .read(locationProvider.notifier)
          .setLocation(LatLng(startLat, startLng));
      ref
          .read(navigationProvider.notifier)
          .setDestination(LatLng(destLat, destLng));

      setState(() => _searchBarExpanded = false);
      FocusScope.of(context).unfocus();
    } on FormatException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid coordinate format.')),
      );
    }
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
              initialZoom: 15.0,
              minZoom: 3.0,
              maxZoom: 18.0,
              onLongPress: _onLongPress,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              // Layer 1: OSM Tiles
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                      strokeWidth: 5.0,
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
                            width: 2,
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
                      width: 40,
                      height: 40,
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.location_on,
                        color: Color(0xFFEF5350),
                        size: 40,
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

          // ── Floating search bar ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSearchBar(),
                  if (_searchBarExpanded) _buildSearchFields(),
                ],
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
          bottom: navState.activeRoute != null ? 100 : 0,
        ),
        child: FloatingActionButton.small(
          onPressed: _initLocation,
          backgroundColor: const Color(0xFF1B2838),
          child: const Icon(Icons.my_location, color: Color(0xFF4FC3F7)),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () => setState(() => _searchBarExpanded = !_searchBarExpanded),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2838).withAlpha(242),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(77),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: Color(0xFF4FC3F7), size: 22),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Search accessible route...',
                style: TextStyle(color: Colors.white54, fontSize: 15),
              ),
            ),
            Icon(
              _searchBarExpanded
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              color: Colors.white38,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchFields() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2838).withAlpha(242),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _startController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Start: lat, lng',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
              prefixIcon: const Icon(
                Icons.trip_origin,
                color: Color(0xFF4CAF50),
                size: 18,
              ),
              filled: true,
              fillColor: const Color(0xFF253547),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _destController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Destination: lat, lng',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
              prefixIcon: const Icon(
                Icons.location_on,
                color: Color(0xFFEF5350),
                size: 18,
              ),
              filled: true,
              fillColor: const Color(0xFF253547),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _handleSearch,
              icon: const Icon(Icons.directions_walk, size: 18),
              label: const Text('Find Route'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
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
