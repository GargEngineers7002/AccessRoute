import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/navigation_provider.dart';
import '../../providers/obstacle_provider.dart';

/// A bottom banner showing route information and bypassed hazard count.
class RouteInfoBanner extends ConsumerWidget {
  /// Creates the route info banner.
  const RouteInfoBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navState = ref.watch(navigationProvider);
    final obstacleCount = ref.watch(obstacleProvider).length;

    final route = navState.activeRoute;
    if (route == null && !navState.isLoading) return const SizedBox.shrink();

    return AnimatedSlide(
      offset: route != null ? Offset.zero : const Offset(0, 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2838).withAlpha(242),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(102),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: navState.isLoading
            ? const _LoadingContent()
            : _RouteContent(
                distance: route!.formattedDistance,
                duration: route.formattedDuration,
                obstacleCount: obstacleCount,
                onClear: () {
                  ref.read(navigationProvider.notifier).clearNavigation();
                },
              ),
      ),
    );
  }
}

class _LoadingContent extends StatelessWidget {
  const _LoadingContent();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 12),
        Text(
          'Calculating accessible route...',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }
}

class _RouteContent extends StatelessWidget {
  const _RouteContent({
    required this.distance,
    required this.duration,
    required this.obstacleCount,
    required this.onClear,
  });

  final String distance;
  final String duration;
  final int obstacleCount;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ETA
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.directions_walk,
                    color: Color(0xFF4FC3F7),
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    duration,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    distance,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (obstacleCount > 0)
                Text(
                  '$obstacleCount hazard${obstacleCount == 1 ? '' : 's'} bypassed',
                  style: const TextStyle(
                    color: Color(0xFFFFB74D),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),

        // Clear button
        IconButton(
          onPressed: onClear,
          icon: const Icon(Icons.close, color: Colors.white54, size: 20),
          tooltip: 'Clear route',
          style: IconButton.styleFrom(
            backgroundColor: Colors.white12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}
