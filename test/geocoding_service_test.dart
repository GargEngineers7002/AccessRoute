import 'package:access_route/services/geocoding_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GeocodingService Unit Tests', () {
    test('Campus presets return immediate matches', () async {
      final service = GeocodingService();
      final results = await service.searchPlaces('lib');

      expect(results.isNotEmpty, isTrue);
      expect(results.any((p) => p.name == 'Library'), isTrue);
      expect(results.first.isCampusPreset, isTrue);
    });

    test('Empty query returns empty list', () async {
      final service = GeocodingService();
      final results = await service.searchPlaces('   ');

      expect(results.isEmpty, isTrue);
    });
  });
}
