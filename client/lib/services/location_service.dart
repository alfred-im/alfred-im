import 'package:geolocator/geolocator.dart';

import '../config/location_config.dart';

class LocationService {
  Future<({double latitude, double longitude})> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceException(
        'Servizi di localizzazione disattivati sul dispositivo.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationServiceException(
        'Permesso posizione negato. Consenti l\'accesso alla posizione nel browser o nelle impostazioni.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationServiceException(
        'Permesso posizione negato in modo permanente. Abilitalo nelle impostazioni del dispositivo.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );

    return (
      latitude: LocationConfig.roundCoordinate(position.latitude),
      longitude: LocationConfig.roundCoordinate(position.longitude),
    );
  }
}

class LocationServiceException implements Exception {
  const LocationServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
