import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/app_constants.dart';
import '../../data/models/category_model.dart';
import '../../data/models/incident_model.dart';
import '../../data/services/location_service.dart';
import '../../data/services/heatmap_service.dart';
import '../../utils/app_theme.dart';
import '../providers/category_provider.dart';
import '../providers/incident_provider.dart';
import '../providers/community_provider.dart';
import '../widgets/incident_bottom_sheet.dart';
import '../widgets/incident_search_delegate.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final _locationService = LocationService();
  bool _isCentering = false;
  bool _showHeatmap = false;
  final Map<IncidentCategory, BitmapDescriptor> _markerIconCache = {};
  final Map<String, BitmapDescriptor> _customMarkerCache = {};
  final Set<String> _loadingCustomCategories = {};
  String? _lastCenteredIncidentId;
  String _currentLocationName = 'Locating...';

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
    _loadLocationName();
  }

  Future<void> _loadLocationName() async {
    final position = await _locationService.getQuickPosition();
    if (position != null && mounted) {
      final name = await _locationService.getShortLocationName(
        position.latitude,
        position.longitude,
      );
      if (mounted) setState(() => _currentLocationName = name);
    }
  }

  Future<void> _loadMarkerIcons() async {
    for (final category in IncidentCategory.values) {
      _markerIconCache[category] = await _buildMarkerFromParams(
        _categoryColor(category), _categoryIconData(category));
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadCustomCategoryMarker(CategoryModel cat) async {
    if (_loadingCustomCategories.contains(cat.name) ||
        _customMarkerCache.containsKey(cat.name)) {
      return;
    }
    _loadingCustomCategories.add(cat.name);
    final marker = await _buildMarkerFromParams(cat.color, cat.icon);
    if (mounted) {
      setState(() {
        _customMarkerCache[cat.name] = marker;
        _loadingCustomCategories.remove(cat.name);
      });
    }
  }

  Future<BitmapDescriptor> _buildMarkerFromParams(Color color, IconData iconData) async {

    // Logical display size
    const double size = 36;
    const double pinHeight = 48;

    // Render at 3× for crisp display on high-DPI screens
    const double scale = 3.0;
    const double scaledSize = size * scale;
    const double scaledPinHeight = pinHeight * scale;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, scaledSize, scaledPinHeight));
    canvas.scale(scale, scale);

    final paint = Paint()..color = color;

    // Draw pin circle (head)
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, paint);

    // Draw pin tail (triangle)
    final path = Path();
    path.moveTo(size * 0.35, size * 0.82);
    path.lineTo(size * 0.65, size * 0.82);
    path.lineTo(size / 2, pinHeight);
    path.close();
    canvas.drawPath(path, paint);

    // White border on circle
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 2, borderPaint);

    // Draw category icon
    final iconPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    iconPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: 16,
        fontFamily: iconData.fontFamily,
        package: iconData.fontPackage,
        color: Colors.white,
      ),
    );
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      Offset(
        (size - iconPainter.width) / 2,
        (size - iconPainter.height) / 2,
      ),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(scaledSize.toInt(), scaledPinHeight.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    // Pass logical width so the map renders it at the correct display size
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List(), width: size);
  }

  Color _categoryColor(IncidentCategory category) {
    switch (category) {
      case IncidentCategory.crime:
        return AppTheme.primaryRed;
      case IncidentCategory.traffic:
        return AppTheme.warningOrange;
      case IncidentCategory.emergency:
        return Colors.pink[700]!;
      case IncidentCategory.infrastructure:
        return Colors.blue;
      case IncidentCategory.environmental:
        return Colors.green[700]!;
      case IncidentCategory.suspicious:
        return Colors.deepPurple;
      case IncidentCategory.other:
        return AppTheme.textSecondary;
    }
  }

  IconData _categoryIconData(IncidentCategory category) {
    switch (category) {
      case IncidentCategory.crime:
        return Icons.shield;
      case IncidentCategory.infrastructure:
        return Icons.construction;
      case IncidentCategory.suspicious:
        return Icons.visibility;
      case IncidentCategory.traffic:
        return Icons.directions_car;
      case IncidentCategory.environmental:
        return Icons.eco;
      case IncidentCategory.emergency:
        return Icons.local_hospital;
      case IncidentCategory.other:
        return Icons.category;
    }
  }

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
            backgroundColor: AppTheme.warningOrange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location timeout - please try again'),
            backgroundColor: AppTheme.warningOrange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCentering = false);
      }
    }
  }

  BitmapDescriptor _markerIcon(IncidentCategory category, SeverityLevel severity, String? customCategoryName) {
    if (category == IncidentCategory.other && customCategoryName != null) {
      return _customMarkerCache[customCategoryName] ??
          _markerIconCache[IncidentCategory.other] ??
          BitmapDescriptor.defaultMarker;
    }
    return _markerIconCache[category] ?? BitmapDescriptor.defaultMarker;
  }

  Set<Marker> _buildMarkers(List<IncidentModel> incidents, List<CategoryModel> customCategories) {
    // Don't show markers when heatmap is enabled
    if (_showHeatmap) return {};

    // Trigger lazy loading for any uncached custom category markers
    for (final cat in customCategories) {
      if (!_customMarkerCache.containsKey(cat.name) &&
          !_loadingCustomCategories.contains(cat.name)) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _loadCustomCategoryMarker(cat));
      }
    }

    return incidents.map((incident) {
      return Marker(
        markerId: MarkerId(incident.id),
        position: LatLng(incident.latitude, incident.longitude),
        icon: _markerIcon(incident.category, incident.severity, incident.customCategoryName),
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

  Set<Circle> _buildHeatmapCircles(List<IncidentModel> incidents) {
    if (!_showHeatmap) return {};

    final heatmapPoints = HeatmapService.calculateHeatmap(incidents);
    return HeatmapService.generateHeatmapCircles(heatmapPoints);
  }

  void _showIncidentSheet(IncidentModel incident) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => IncidentBottomSheet(
        incidentId: incident.id,
        onViewOnMap: () {
          Navigator.pop(context);
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(incident.latitude, incident.longitude),
              16,
            ),
          );
        },
      ),
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
                color: AppTheme.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.search, color: AppTheme.primaryDark),
              title: const Text('Search Incidents'),
              onTap: () {
                Navigator.pop(ctx);
                _showSearch();
              },
            ),
            ListTile(
              leading: const Icon(Icons.filter_list, color: AppTheme.primaryDark),
              title: const Text('Advanced Filters'),
              onTap: () {
                Navigator.pop(ctx);
                _showFilterSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh, color: AppTheme.primaryDark),
              title: const Text('Refresh Incidents'),
              onTap: () {
                Navigator.pop(ctx);
                context.read<IncidentProvider>().loadIncidents();
              },
            ),
            ListTile(
              leading: const Icon(Icons.clear_all, color: AppTheme.primaryDark),
              title: const Text('Clear All Filters'),
              onTap: () {
                Navigator.pop(ctx);
                context.read<IncidentProvider>().clearAllFilters();
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

  void _showSearch() {
    showSearch(
      context: context,
      delegate: IncidentSearchDelegate(
        onIncidentSelected: (incident) {
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(incident.latitude, incident.longitude),
              16,
            ),
          );
          _showIncidentSheet(incident);
        },
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _FilterSheet(
          scrollController: scrollController,
          onDateRangeTap: () => _selectDateRange(context),
        ),
      ),
    );
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final provider = context.read<IncidentProvider>();
    final now = DateTime.now();
    final initialRange = provider.dateRange ??
        DateTimeRange(
          start: now.subtract(const Duration(days: 7)),
          end: now,
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      initialDateRange: initialRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppTheme.primaryRed,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      provider.setDateRange(picked);
    }
  }

  int _countActiveFilters(IncidentProvider provider) {
    int count = 0;
    count += provider.activeFilters.length;
    count += provider.severityFilters.length;
    count += provider.statusFilters.length;
    if (provider.dateRange != null) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<IncidentProvider, CommunityProvider, CategoryProvider>(
      builder: (context, provider, communityProvider, categoryProvider, _) {
        final myApprovedIds = communityProvider.myApprovedCommunityIds;
        final bannedCommunityIds = communityProvider.communities
            .where((c) => c.isActivelySuspended)
            .map((c) => c.id)
            .toSet();
        // Show community incidents the user is an approved member of, excluding banned communities
        final incidents = provider.incidents
            .where((i) =>
                i.status != IncidentStatus.pending &&
                i.status != IncidentStatus.dismissed &&
                i.status != IncidentStatus.resolved &&
                (i.communityIds.isEmpty ||
                    i.communityIds.any((id) => myApprovedIds.contains(id))) &&
                !i.communityIds.any((id) => bannedCommunityIds.contains(id)))
            .toList();
        final customCategories =
            categoryProvider.enabledCategories.where((c) => !c.isDefault).toList();
        // Center camera on a selected incident (set by "View on Map" from other screens)
        final selectedIncident = provider.selectedIncident;
        if (selectedIncident != null && selectedIncident.id != _lastCenteredIncidentId) {
          _lastCenteredIncidentId = selectedIncident.id;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _mapController != null) {
              _mapController!.animateCamera(
                CameraUpdate.newLatLngZoom(
                  LatLng(selectedIncident.latitude, selectedIncident.longitude),
                  16,
                ),
              );
              context.read<IncidentProvider>().selectIncident(null);
            }
          });
        }
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
              onMapCreated: (controller) {
                _mapController = controller;
                _centerOnUserLocation();
              },
              markers: _buildMarkers(incidents, customCategories),
              circles: _buildHeatmapCircles(incidents),
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
                      _currentLocationName,
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
                    // Search button
                    _FilterChipWidget(
                      label: 'Search',
                      icon: Icons.search,
                      isSelected: false,
                      onTap: _showSearch,
                    ),
                    const SizedBox(width: 8),
                    // Filters button with badge
                    _FilterChipWidget(
                      label: 'Filters',
                      icon: Icons.tune,
                      isSelected: provider.hasActiveFilters,
                      onTap: _showFilterSheet,
                      badge: provider.hasActiveFilters
                          ? _countActiveFilters(provider)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    _FilterChipWidget(
                      label: 'Last 24h',
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
            // Heatmap toggle button
            Positioned(
              bottom: 160,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: _showHeatmap ? AppTheme.primaryRed : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _showHeatmap ? AppTheme.primaryRed : AppTheme.cardBorder,
                  ),
                ),
                child: IconButton(
                  onPressed: () {
                    setState(() => _showHeatmap = !_showHeatmap);
                  },
                  tooltip: _showHeatmap ? 'Hide Heatmap' : 'Show Heatmap',
                  icon: Icon(
                    Icons.blur_on,
                    color: _showHeatmap ? Colors.white : AppTheme.primaryDark,
                  ),
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
  final int? badge;

  const _FilterChipWidget({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
    this.badge,
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
            if (badge != null && badge! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterSheet extends StatelessWidget {
  final ScrollController scrollController;
  final VoidCallback onDateRangeTap;

  const _FilterSheet({
    required this.scrollController,
    required this.onDateRangeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<IncidentProvider>(
      builder: (context, provider, _) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Filters', style: Theme.of(context).textTheme.headlineSmall),
                if (provider.hasActiveFilters)
                  TextButton(
                    onPressed: () => provider.clearAllFilters(),
                    child: const Text('Clear All',
                        style: TextStyle(color: AppTheme.primaryRed)),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Date Range
            _FilterSection(
              title: 'Date Range',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip(
                        'Last 24 hours',
                        provider.activeFilters.contains('Last 24 hours'),
                        () => provider.toggleFilter('Last 24 hours'),
                      ),
                      _buildFilterChip(
                        'Custom Range',
                        provider.dateRange != null,
                        onDateRangeTap,
                      ),
                    ],
                  ),
                  if (provider.dateRange != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${DateFormat('MMM d').format(provider.dateRange!.start)} - ${DateFormat('MMM d').format(provider.dateRange!.end)}',
                      style: AppTheme.caption,
                    ),
                  ],
                ],
              ),
            ),

            // Severity
            _FilterSection(
              title: 'Severity',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: SeverityLevel.values.map((severity) {
                  final label = severity.name[0].toUpperCase() +
                      severity.name.substring(1);
                  return _buildFilterChip(
                    label,
                    provider.severityFilters.contains(severity),
                    () => provider.toggleSeverityFilter(severity),
                    color: _severityColor(severity),
                  );
                }).toList(),
              ),
            ),

            // Status
            _FilterSection(
              title: 'Status',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: IncidentStatus.values
                    .where((s) =>
                        s != IncidentStatus.pending &&
                        s != IncidentStatus.dismissed &&
                        s != IncidentStatus.resolved)
                    .map((status) {
                  final label = _statusLabel(status);
                  return _buildFilterChip(
                    label,
                    provider.statusFilters.contains(status),
                    () => provider.toggleStatusFilter(status),
                  );
                }).toList(),
              ),
            ),

            // Categories
            _FilterSection(
              title: 'Categories',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: IncidentCategory.values.map((cat) {
                  final label =
                      cat.name[0].toUpperCase() + cat.name.substring(1);
                  return _buildFilterChip(
                    label,
                    provider.activeFilters.contains(label),
                    () => provider.toggleFilter(label),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Show ${provider.incidents.length} Results'),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(
    String label,
    bool isSelected,
    VoidCallback onTap, {
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (color ?? AppTheme.primaryDark)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (color ?? AppTheme.primaryDark)
                : AppTheme.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: isSelected ? Colors.white : AppTheme.primaryDark,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Color _severityColor(SeverityLevel severity) {
    switch (severity) {
      case SeverityLevel.low:
        return AppTheme.successGreen;
      case SeverityLevel.moderate:
        return AppTheme.warningOrange;
      case SeverityLevel.high:
        return AppTheme.primaryRed;
    }
  }

  String _statusLabel(IncidentStatus status) {
    switch (status) {
      case IncidentStatus.pending:
        return 'Pending';
      case IncidentStatus.underReview:
        return 'Under Review';
      case IncidentStatus.verified:
        return 'Verified';
      case IncidentStatus.resolved:
        return 'Resolved';
      case IncidentStatus.dismissed:
        return 'Dismissed';
    }
  }
}

class _FilterSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _FilterSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
