import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import '../../config/app_constants.dart';

class LocationService {
  static String get _apiKey => AppConstants.googleMapsApiKey;
  Future<Position?> getCurrentPosition({bool fast = false}) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    // For fast mode, try last known position first
    if (fast) {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) return lastKnown;
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: fast ? LocationAccuracy.medium : LocationAccuracy.high,
      timeLimit: Duration(seconds: fast ? 5 : 15),
    );
  }

  /// Get position quickly - uses last known or medium accuracy
  Future<Position?> getQuickPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    // Try last known position first (instant)
    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null) return lastKnown;

    // Fall back to current position with medium accuracy
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: const Duration(seconds: 5),
    );
  }

  /// Returns a short display name like "Setapak, Selangor"
  Future<String> getShortLocationName(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[
          if (p.subLocality != null && p.subLocality!.isNotEmpty) p.subLocality!,
          if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) p.administrativeArea!,
        ];
        if (parts.isNotEmpty) return parts.join(', ');
        // fallback to locality
        if (p.locality != null && p.locality!.isNotEmpty) return p.locality!;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting short location name: $e');
    }
    return 'Unknown location';
  }

  Future<String> getAddressFromCoordinates(
      double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[
          if (p.street != null && p.street!.isNotEmpty) p.street!,
          if (p.subLocality != null && p.subLocality!.isNotEmpty)
            p.subLocality!,
          if (p.locality != null && p.locality!.isNotEmpty) p.locality!,
        ];
        return parts.join(', ');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting address from coordinates: $e');
    }
    return 'Unknown location';
  }

  /// Get autocomplete suggestions for an address query, biased to user's location
  Future<List<PlaceSuggestion>> getAddressSuggestions(
    String query, {
    double? latitude,
    double? longitude,
    int radiusMeters = 50000, // 50km — roughly within the same state
  }) async {
    if (query.isEmpty) return [];

    try {
      String urlStr =
          'https://maps.googleapis.com/maps/api/place/autocomplete/json'
          '?input=${Uri.encodeComponent(query)}'
          '&types=address'
          '&key=$_apiKey';

      if (latitude != null && longitude != null) {
        urlStr += '&location=$latitude,$longitude'
            '&radius=$radiusMeters'
            '&strictbounds=true';
      }

      final url = Uri.parse(urlStr);

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List;
          return predictions
              .map((p) => PlaceSuggestion(
                    placeId: p['place_id'],
                    description: p['description'],
                  ))
              .toList();
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting address suggestions: $e');
    }
    return [];
  }

  /// Get coordinates from a place ID
  Future<LatLngResult?> getCoordinatesFromPlaceId(String placeId) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId'
        '&fields=geometry'
        '&key=$_apiKey',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final location = data['result']['geometry']['location'];
          return LatLngResult(
            latitude: location['lat'],
            longitude: location['lng'],
          );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting coordinates from place ID: $e');
    }
    return null;
  }

  /// Get coordinates from an address string
  Future<LatLngResult?> getCoordinatesFromAddress(String address) async {
    if (address.isEmpty) return null;

    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return LatLngResult(
          latitude: locations.first.latitude,
          longitude: locations.first.longitude,
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting coordinates from address: $e');
    }
    return null;
  }
}

class PlaceSuggestion {
  final String placeId;
  final String description;

  PlaceSuggestion({required this.placeId, required this.description});
}

class LatLngResult {
  final double latitude;
  final double longitude;

  LatLngResult({required this.latitude, required this.longitude});
}
