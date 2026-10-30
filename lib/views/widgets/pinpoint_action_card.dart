import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Floating action card displayed when the user taps on the map to set a pinpoint.
class PinpointActionCard extends StatelessWidget {
  /// Creates a [PinpointActionCard].
  const PinpointActionCard({
    super.key,
    required this.pinpoint,
    required this.onRouteHere,
    required this.onDismiss,
  });

  /// The coordinates of the pinpoint.
  final LatLng pinpoint;

  /// Callback when user taps "Route Here".
  final VoidCallback onRouteHere;

  /// Callback when user dismisses the card.
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2838).withAlpha(245),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFAB47BC).withAlpha(120), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFAB47BC).withAlpha(40),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.place_rounded,
              color: Color(0xFFCE93D8),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selected Pinpoint',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${pinpoint.latitude.toStringAsFixed(5)}, ${pinpoint.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onRouteHere,
            icon: const Icon(Icons.directions_walk, size: 18),
            label: const Text('Route Here'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close, color: Colors.white54, size: 20),
            tooltip: 'Dismiss Pinpoint',
          ),
        ],
      ),
    );
  }
}
