import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../config/app_constants.dart';
import '../../data/models/incident_model.dart';
import '../../data/services/location_service.dart';
import '../../utils/app_theme.dart';
import '../providers/incident_provider.dart';
import '../widgets/incident_bottom_sheet.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final _locationService = LocationService();
  bool _isCentering = false;

  Future<void> _centerOnUserLocation() async {
    if (_isCentering) return;

    setState(() => _isCentering = true);

    try {
      // Use quick position for faster response
      final position = await _locationService.getQuickPosition();
      if (position != null && mounted) {
        await _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude),
            15,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to get current location'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location timeout - please try again'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCentering = false);
      }
    }
  }

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
      builder: (_) => IncidentBottomSheet(incidentId: incident.id),
    );
  }

  void _showMapMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.refresh, color: AppTheme.primaryDark),
              title: const Text('Refresh Incidents'),
              onTap: () {
                Navigator.pop(ctx);
                context.read<IncidentProvider>().loadIncidents();
              },
            ),
            ListTile(
              leading: const Icon(Icons.filter_list, color: AppTheme.primaryDark),
              title: const Text('Clear Filters'),
              onTap: () {
                Navigator.pop(ctx);
                final provider = context.read<IncidentProvider>();
                for (final filter in provider.activeFilters.toList()) {
                  provider.toggleFilter(filter);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.my_location, color: AppTheme.primaryDark),
              title: const Text('Center on My Location'),
              onTap: () {
                Navigator.pop(ctx);
                _centerOnUserLocation();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
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
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
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
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.menu, color: AppTheme.primaryDark),
                      onPressed: () => _showMapMenu(context),
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
              bottom: 100,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: IconButton(
                  onPressed: _isCentering ? null : _centerOnUserLocation,
                  icon: _isCentering
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryDark,
                          ),
                        )
                      : const Icon(Icons.my_location, color: AppTheme.primaryDark),
                ),
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
          border: Border.all(
            color: isSelected ? AppTheme.primaryDark : AppTheme.cardBorder,
          ),
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
                fontFamily: AppTheme.fontFamily,
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
