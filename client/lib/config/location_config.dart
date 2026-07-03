/// Static location message contract — coordinates + OSM tiles (no API key).
class LocationConfig {
  LocationConfig._();

  static const coordinateDecimals = 5;
  static const mapZoom = 15.0;
  static const refiningAccuracyThresholdMeters = 50.0;
  static const osmTileUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const osmAttribution = '© OpenStreetMap';

  static double roundCoordinate(double value) {
    final factor = _pow10(coordinateDecimals);
    return (value * factor).round() / factor;
  }

  static String formatCoordinates(double latitude, double longitude) {
    final lat = roundCoordinate(latitude);
    final lng = roundCoordinate(longitude);
    final latSuffix = lat >= 0 ? 'N' : 'S';
    final lngSuffix = lng >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(coordinateDecimals)}°$latSuffix, '
        '${lng.abs().toStringAsFixed(coordinateDecimals)}°$lngSuffix';
  }

  static String openInMapsUrl(double latitude, double longitude) {
    final lat = roundCoordinate(latitude);
    final lng = roundCoordinate(longitude);
    return 'https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=${mapZoom.round()}/$lat/$lng';
  }

  static double _pow10(int exponent) {
    var result = 1.0;
    for (var i = 0; i < exponent; i++) {
      result *= 10;
    }
    return result;
  }
}
