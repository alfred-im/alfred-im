import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/config/location_config.dart';
import 'package:alfred_client/models/location_reading.dart';

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

    test('uses live OSM tile template', () {
      expect(
        LocationConfig.osmTileUrlTemplate,
        contains('tile.openstreetmap.org'),
      );
    });

    test('builds open-in-maps URL', () {
      final openUrl = LocationConfig.openInMapsUrl(45.0, 9.0);
      expect(openUrl, contains('openstreetmap.org'));
      expect(openUrl, contains('mlat=45'));
      expect(openUrl, contains('mlon=9'));
    });
  });

  group('LocationReading', () {
    test('marks rough fixes as refining', () {
      const reading = LocationReading(
        latitude: 45,
        longitude: 9,
        accuracyMeters: 120,
      );
      expect(reading.isRefining, isTrue);
      expect(reading.accuracyLabel, contains('miglioramento'));
    });

    test('marks accurate fixes as ready', () {
      const reading = LocationReading(
        latitude: 45,
        longitude: 9,
        accuracyMeters: 12,
      );
      expect(reading.isRefining, isFalse);
      expect(reading.accuracyLabel, contains('12 m'));
    });
  });
}
