import 'package:access_route/models/obstacle.dart';
import 'package:access_route/services/campus_graph_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('CampusGraphService Tests', () {
    final service = CampusGraphService();

    final start = CampusGraphService.nodes['n_old_building']!;
    final library = CampusGraphService.nodes['n_library_entrance']!;

    test('Computes direct route through lower path when clear', () {
      final route = service.findCampusRoute(start, library, []);
      expect(route, isNotNull);
      expect(route!.points.isNotEmpty, isTrue);

      // Verify that the route uses n_lower_path_mid (lower direct route)
      final lowerMid = CampusGraphService.nodes['n_lower_path_mid']!;
      final usesLowerPath = route.points.any(
        (p) => const Distance().as(LengthUnit.Meter, p, lowerMid) < 3.0,
      );
      expect(usesLowerPath, isTrue);
    });

    test('Reroutes through upper campus path when lower path has obstacle', () {
      final lowerMid = CampusGraphService.nodes['n_lower_path_mid']!;

      final obstacle = Obstacle(
        id: 'obs-1',
        position: lowerMid,
        title: 'Broken Pavement',
        type: ObstacleType.construction,
        reportedAt: DateTime.now(),
      );

      final route = service.findCampusRoute(start, library, [obstacle]);
      expect(route, isNotNull);

      // Lower path should now be completely avoided
      final usesLowerPath = route!.points.any(
        (p) => const Distance().as(LengthUnit.Meter, p, lowerMid) < 15.0,
      );
      expect(usesLowerPath, isFalse);

      // Route should use upper detour (n_upper_west_corner or n_library_north)
      final upperNorth = CampusGraphService.nodes['n_library_north']!;
      final usesUpperPath = route.points.any(
        (p) => const Distance().as(LengthUnit.Meter, p, upperNorth) < 3.0,
      );
      expect(usesUpperPath, isTrue);
    });

    test('Returns null when both paths are blocked', () {
      final lowerMid = CampusGraphService.nodes['n_lower_path_mid']!;
      final upperNorth = CampusGraphService.nodes['n_library_north']!;

      final obstacles = [
        Obstacle(
          id: 'obs-1',
          position: lowerMid,
          title: 'Lower Blocked',
          type: ObstacleType.construction,
          reportedAt: DateTime.now(),
        ),
        Obstacle(
          id: 'obs-2',
          position: upperNorth,
          title: 'Upper Blocked',
          type: ObstacleType.stairs,
          reportedAt: DateTime.now(),
        ),
      ];

      final route = service.findCampusRoute(start, library, obstacles);
      expect(route, isNull);
    });
  });
}
