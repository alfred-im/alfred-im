import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/config/location_config.dart';

void main() {
  group('LocationConfig', () {
    test('rounds coordinates to configured precision', () {
      expect(LocationConfig.roundCoordinate(45.123456789), 45.12346);
      expect(LocationConfig.roundCoordinate(-9.999994), -9.99999);
    });

    test('formats coordinates with hemisphere suffix', () {
      expect(
        LocationConfig.formatCoordinates(45.12345, 9.54321),
        '45.12345°N, 9.54321°E',
      );
      expect(
        LocationConfig.formatCoordinates(-33.5, -70.6),
        '33.50000°S, 70.60000°W',
      );
    });

    test('builds static map and open URLs', () {
      final mapUrl = LocationConfig.staticMapUrl(45.0, 9.0);
      expect(mapUrl, contains('staticmap.openstreetmap.de'));
      expect(mapUrl, contains('45.0,9.0'));

      final openUrl = LocationConfig.openInMapsUrl(45.0, 9.0);
      expect(openUrl, contains('openstreetmap.org'));
      expect(openUrl, contains('mlat=45'));
      expect(openUrl, contains('mlon=9'));
    });
  });
}
