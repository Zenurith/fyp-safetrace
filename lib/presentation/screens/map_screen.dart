import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../config/app_constants.dart';
import '../../data/models/incident_model.dart';
import '../../utils/app_theme.dart';
import '../providers/incident_provider.dart';
import '../widgets/incident_bottom_sheet.dart';
import 'report_incident_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;

  BitmapDescriptor _markerIcon(IncidentCategory category, SeverityLevel severity) {
    double hue;
    switch (category) {
      case IncidentCategory.crime:
        hue = BitmapDescriptor.hueRed;
        break;
      case IncidentCategory.traffic:
        hue = BitmapDescriptor.hueOrange;
        break;
      case IncidentCategory.emergency:
        hue = BitmapDescriptor.hueRose;
        break;
      case IncidentCategory.infrastructure:
        hue = BitmapDescriptor.hueAzure;
        break;
      case IncidentCategory.environmental:
        hue = BitmapDescriptor.hueGreen;
        break;
      case IncidentCategory.suspicious:
        hue = BitmapDescriptor.hueViolet;
        break;
    }
    return BitmapDescriptor.defaultMarkerWithHue(hue);
  }

  Set<Marker> _buildMarkers(List<IncidentModel> incidents) {
    return incidents.map((incident) {
      return Marker(
        markerId: MarkerId(incident.id),
        position: LatLng(incident.latitude, incident.longitude),
        icon: _markerIcon(incident.category, incident.severity),
        infoWindow: InfoWindow(
          title: '${incident.categoryLabel} - ${incident.title}',
          snippet: 'Reported ${incident.timeAgo}',
        ),
        onTap: () {
          context.read<IncidentProvider>().selectIncident(incident);
          _showIncidentSheet(incident);
        },
      );
    }).toSet();
  }

  void _showIncidentSheet(IncidentModel incident) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => IncidentBottomSheet(incident: incident),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<IncidentProvider>(
      builder: (context, provider, _) {
        final incidents = provider.incidents;
        return Stack(
          children: [
            GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(
                  AppConstants.defaultLat,
                  AppConstants.defaultLng,
                ),
                zoom: AppConstants.defaultZoom,
              ),
              onMapCreated: (controller) => _mapController = controller,
              markers: _buildMarkers(incidents),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            ),
            // Location header
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Setapak, Selangor',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryDark,
                        shadows: [
                          Shadow(
                            color: Colors.white.withValues(alpha: 0.8),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.menu, color: AppTheme.primaryDark),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
            // Filter chips
            Positioned(
              top: MediaQuery.of(context).padding.top + 56,
              left: 16,
              right: 16,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChipWidget(
                      label: 'Last 24 hours',
                      icon: Icons.access_time,
                      isSelected: provider.activeFilters.contains('Last 24 hours'),
                      onTap: () => provider.toggleFilter('Last 24 hours'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipWidget(
                      label: 'Crime',
                      isSelected: provider.activeFilters.contains('Crime'),
                      onTap: () => provider.toggleFilter('Crime'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipWidget(
                      label: 'Traffic',
                      isSelected: provider.activeFilters.contains('Traffic'),
                      onTap: () => provider.toggleFilter('Traffic'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipWidget(
                      label: 'Emergency',
                      isSelected: provider.activeFilters.contains('Emergency'),
                      onTap: () => provider.toggleFilter('Emergency'),
                    ),
                  ],
                ),
              ),
            ),
            // My location button
            Positioned(
              bottom: 24,
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'location',
                backgroundColor: Colors.white,
                onPressed: () {
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLng(
                      const LatLng(
                        AppConstants.defaultLat,
                        AppConstants.defaultLng,
                      ),
                    ),
                  );
                },
                child: const Icon(Icons.my_location, color: AppTheme.primaryDark),
              ),
            ),
            // FAB to report
            Positioned(
              bottom: 24,
              left: 16,
              child: FloatingActionButton(
                heroTag: 'report',
                backgroundColor: AppTheme.primaryRed,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ReportIncidentScreen(),
                    ),
                  );
                },
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FilterChipWidget extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChipWidget({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: isSelected ? Colors.white : AppTheme.primaryDark),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.primaryDark,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
