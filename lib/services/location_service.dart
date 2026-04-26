// lib/services/location_service.dart

import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  Future<Position?> getCurrentPosition() async {
    final hasPermission = await checkAndRequestPermission();
    if (!hasPermission) return null;

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<String> getAddressFromCoordinates(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return '$lat, $lng';
      final p = placemarks.first;
      final parts = [
        p.street,
        p.locality,
        p.postalCode,
        p.country,
      ].where((s) => s != null && s.isNotEmpty).toList();
      return parts.join(', ');
    } catch (_) {
      return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
    }
  }
}
