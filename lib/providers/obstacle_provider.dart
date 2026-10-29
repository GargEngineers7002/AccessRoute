import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/obstacle.dart';

/// Provides the list of active accessibility obstacles.
final obstacleProvider =
    StateNotifierProvider<ObstacleNotifier, List<Obstacle>>((ref) {
  return ObstacleNotifier();
});

/// Manages the in-memory list of reported obstacles.
class ObstacleNotifier extends StateNotifier<List<Obstacle>> {
  /// Creates an empty obstacle list.
  ObstacleNotifier() : super(const []);

  /// Adds [obstacle] to the active list.
  void addObstacle(Obstacle obstacle) {
    state = [...state, obstacle];
  }

  /// Removes the obstacle with the given [id].
  void removeObstacle(String id) {
    state = state.where((o) => o.id != id).toList();
  }

  /// Removes all obstacles.
  void clearAll() {
    state = const [];
  }
}
