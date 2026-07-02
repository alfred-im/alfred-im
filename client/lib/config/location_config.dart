/// Static location message contract — coordinates + OSM preview (no API key).
class LocationConfig {
  LocationConfig._();

  static const coordinateDecimals = 5;
  static const mapWidth = 400;
  static const mapHeight = 200;
  static const mapZoom = 15;

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

  /// OpenStreetMap static map (no API key).
  static String staticMapUrl(double latitude, double longitude) {
    final lat = roundCoordinate(latitude);
    final lng = roundCoordinate(longitude);
    return 'https://staticmap.openstreetmap.de/staticmap.php'
        '?center=$lat,$lng'
        '&zoom=$mapZoom'
        '&size=${mapWidth}x$mapHeight'
        '&markers=$lat,$lng,red-pushpin';
  }

  static String openInMapsUrl(double latitude, double longitude) {
    final lat = roundCoordinate(latitude);
    final lng = roundCoordinate(longitude);
    return 'https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=$mapZoom/$lat/$lng';
  }

  static double _pow10(int exponent) {
    var result = 1.0;
    for (var i = 0; i < exponent; i++) {
      result *= 10;
    }
    return result;
  }
}
