import '../config/location_config.dart';

/// GPS sample while acquiring or refining position before send.
class LocationReading {
  const LocationReading({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double? accuracyMeters;

  double get roundedLatitude => LocationConfig.roundCoordinate(latitude);

  double get roundedLongitude => LocationConfig.roundCoordinate(longitude);

  /// Rough fix still improving (used for status text in preview).
  bool get isRefining {
    final accuracy = accuracyMeters;
    if (accuracy == null) return true;
    return accuracy > LocationConfig.refiningAccuracyThresholdMeters;
  }

  String get accuracyLabel {
    final accuracy = accuracyMeters;
    if (accuracy == null) return 'Precisione in miglioramento…';
    if (accuracy <= LocationConfig.refiningAccuracyThresholdMeters) {
      return 'Precisione ~${accuracy.round()} m';
    }
    return 'Precisione in miglioramento… (~${accuracy.round()} m)';
  }
}
