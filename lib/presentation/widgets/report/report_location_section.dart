import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../data/services/location_service.dart';
import '../../../utils/app_theme.dart';

class ReportLocationSection extends StatelessWidget {
  final double latitude;
  final double longitude;
  final TextEditingController addressController;
  final FocusNode addressFocusNode;
  final bool loadingLocation;
  final bool locationTooFar;
  final double? userCurrentLat;
  final double? userCurrentLng;
  final List<PlaceSuggestion> suggestions;
  final bool showSuggestions;
  final String formattedDistance;
  final void Function(GoogleMapController) onMapCreated;
  final void Function(LatLng) onMapTap;
  final VoidCallback onDetectLocation;
  final VoidCallback onOpenFullScreenMap;
  final Future<void> Function(PlaceSuggestion) onSuggestionSelected;
  final VoidCallback onClearAddress;

  const ReportLocationSection({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.addressController,
    required this.addressFocusNode,
    required this.loadingLocation,
    required this.locationTooFar,
    required this.userCurrentLat,
    required this.userCurrentLng,
    required this.suggestions,
    required this.showSuggestions,
    required this.formattedDistance,
    required this.onMapCreated,
    required this.onMapTap,
    required this.onDetectLocation,
    required this.onOpenFullScreenMap,
    required this.onSuggestionSelected,
    required this.onClearAddress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Location',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryRed,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: double.infinity,
            height: 180,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(latitude, longitude),
                    zoom: 15,
                  ),
                  onMapCreated: onMapCreated,
                  markers: {
                    Marker(
                      markerId: const MarkerId('incident_location'),
                      position: LatLng(latitude, longitude),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueRed,
                      ),
                    ),
                  },
                  onTap: onMapTap,
                  zoomControlsEnabled: false,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                ),
                if (loadingLocation)
                  Container(
                    color: Colors.white.withValues(alpha: 0.7),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Tap map to adjust location',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: onOpenFullScreenMap,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.fullscreen,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: addressController,
              focusNode: addressFocusNode,
              decoration: InputDecoration(
                labelText: 'Address',
                hintText: 'Type to search address...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: addressController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: onClearAddress,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onSubmitted: (value) {
                // handled by parent via controller listener
              },
            ),
            if (showSuggestions && suggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = suggestions[index];
                    return ListTile(
                      leading: const Icon(Icons.location_on_outlined,
                          color: AppTheme.primaryRed),
                      title: Text(
                        suggestion.description,
                        style: const TextStyle(fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => onSuggestionSelected(suggestion),
                    );
                  },
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: loadingLocation ? null : onDetectLocation,
              icon: const Icon(Icons.my_location, size: 16),
              label: const Text('Use Current Location'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            if (userCurrentLat != null &&
                !locationTooFar &&
                !loadingLocation &&
                formattedDistance.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                formattedDistance,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
        if (locationTooFar)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppTheme.primaryRed.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppTheme.primaryRed, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Location is $formattedDistance away. '
                    'You can only report incidents within 5 km of your current location.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryRed,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
