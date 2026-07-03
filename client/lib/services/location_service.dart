import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../models/location_reading.dart';

class LocationService {
  Stream<LocationReading> watchCurrentPosition() async* {
    await _ensureReady();

    yield* Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    ).map(_readingFromPosition);
  }

  Future<void> _ensureReady() async {
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
  }

  LocationReading _readingFromPosition(Position position) {
    return LocationReading(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
    );
  }
}

class LocationServiceException implements Exception {
  const LocationServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
