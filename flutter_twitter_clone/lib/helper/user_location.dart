import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// A location problem the user can act on, with a message to show them.
class LocationException implements Exception {
  LocationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Returns the user's current place, such as "Manila, Metro Manila, Philippines".
/// Asks for location permission first when it has not been decided yet.
Future<String> currentPlaceName() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw LocationException('Turn on Location (GPS) in your phone settings.');
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    // Shows the system permission prompt.
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied) {
    throw LocationException('Location permission was not allowed.');
  }
  if (permission == LocationPermission.deniedForever) {
    throw LocationException(
        'Location permission is blocked. Allow it in the app settings.');
  }

  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.medium,
      timeLimit: Duration(seconds: 20),
    ),
  );

  final places = await placemarkFromCoordinates(
    position.latitude,
    position.longitude,
  );
  if (places.isEmpty) {
    throw LocationException('Could not find a place name for your location.');
  }

  final place = places.first;
  final parts = <String>[];
  for (final part in [
    place.locality,
    place.subAdministrativeArea,
    place.administrativeArea,
    place.country,
  ]) {
    final value = (part ?? '').trim();
    if (value.isNotEmpty && !parts.contains(value)) parts.add(value);
    if (parts.length == 3) break;
  }
  if (parts.isEmpty) {
    throw LocationException('Could not find a place name for your location.');
  }
  return parts.join(', ');
}


