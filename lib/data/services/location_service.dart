import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

class LocationService {
  static const String _apiKey = 'AIzaSyAs0PNHYH4X3mwsJQZqdZ9q778eISZ4ifw';
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
    } catch (_) {}
    return 'Unknown location';
  }

  /// Get autocomplete suggestions for an address query
  Future<List<PlaceSuggestion>> getAddressSuggestions(String query) async {
    if (query.isEmpty) return [];

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(query)}'
        '&types=address'
        '&key=$_apiKey',
      );

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
    } catch (_) {}
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
    } catch (_) {}
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
    } catch (_) {}
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
