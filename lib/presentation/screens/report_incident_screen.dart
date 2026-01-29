// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../data/models/incident_model.dart';
import '../../data/services/location_service.dart';
import '../../config/app_constants.dart';
import '../../utils/app_theme.dart';
import '../providers/incident_provider.dart';

class ReportIncidentScreen extends StatefulWidget {
  const ReportIncidentScreen({super.key});

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final _descriptionController = TextEditingController();
  final _locationService = LocationService();
  final _imagePicker = ImagePicker();

  GoogleMapController? _mapController;
  IncidentCategory _selectedCategory = IncidentCategory.crime;
  SeverityLevel _selectedSeverity = SeverityLevel.moderate;
  bool _isAnonymous = true;
  double _latitude = AppConstants.defaultLat;
  double _longitude = AppConstants.defaultLng;
  String _address = 'Detecting location...';
  bool _loadingLocation = true;
  bool _submitting = false;
  final List<XFile> _mediaFiles = [];

  @override
  void initState() {
    super.initState();
    _detectLocation();
  }

  Future<void> _detectLocation() async {
    setState(() => _loadingLocation = true);
    try {
      final pos = await _locationService.getCurrentPosition();
      if (pos != null && mounted) {
        final addr = await _locationService.getAddressFromCoordinates(
            pos.latitude, pos.longitude);
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
          _address = addr;
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(LatLng(_latitude, _longitude)),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _address = 'Unable to detect location');
      }
    }
    if (mounted) setState(() => _loadingLocation = false);
  }

  Future<void> _adjustLocation() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (context) => _LocationPickerScreen(
          initialLocation: LatLng(_latitude, _longitude),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
        _loadingLocation = true;
      });
      final addr = await _locationService.getAddressFromCoordinates(
          result.latitude, result.longitude);
      if (mounted) {
        setState(() {
          _address = addr;
          _loadingLocation = false;
        });
      }
    }
  }

  Future<void> _pickMedia() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(context);
                final photo = await _imagePicker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 1920,
                  maxHeight: 1080,
                  imageQuality: 85,
                );
                if (photo != null && mounted) {
                  setState(() => _mediaFiles.add(photo));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Record Video'),
              onTap: () async {
                Navigator.pop(context);
                final video = await _imagePicker.pickVideo(
                  source: ImageSource.camera,
                  maxDuration: const Duration(minutes: 2),
                );
                if (video != null && mounted) {
                  setState(() => _mediaFiles.add(video));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final files = await _imagePicker.pickMultiImage(
                  maxWidth: 1920,
                  maxHeight: 1080,
                  imageQuality: 85,
                );
                if (mounted && files.isNotEmpty) {
                  setState(() => _mediaFiles.addAll(files));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _removeMedia(int index) {
    setState(() => _mediaFiles.removeAt(index));
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      // Store local file paths (media only visible on this device)
      final mediaUrls = _mediaFiles.map((f) => f.path).toList();

      final provider = context.read<IncidentProvider>();
      await provider.reportIncident(
        title: _getCategoryLabel(_selectedCategory),
        category: _selectedCategory,
        severity: _selectedSeverity,
        description: _descriptionController.text.trim().isEmpty
            ? 'No description provided.'
            : _descriptionController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        address: _address,
        isAnonymous: _isAnonymous,
        mediaUrls: mediaUrls,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Incident reported successfully'),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to report incident: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Incident'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location Section
            const Text(
              'Location',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryDark,
              ),
            ),
            const SizedBox(height: 12),
            // Mini Map with crosshairs
            Container(
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(_latitude, _longitude),
                      zoom: 16,
                    ),
                    onMapCreated: (controller) => _mapController = controller,
                    zoomControlsEnabled: false,
                    scrollGesturesEnabled: false,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                    zoomGesturesEnabled: false,
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    mapToolbarEnabled: false,
                  ),
                  // Crosshairs overlay
                  Center(
                    child: CustomPaint(
                      size: const Size(60, 60),
                      painter: _CrosshairsPainter(),
                    ),
                  ),
                  // Location pin
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      child: const Icon(
                        Icons.location_on,
                        color: AppTheme.primaryRed,
                        size: 40,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Address display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Automatically detected:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _loadingLocation ? 'Detecting location...' : _address,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (_loadingLocation)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryRed,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Adjust Location button
            OutlinedButton.icon(
              onPressed: _adjustLocation,
              icon: const Icon(Icons.location_on, size: 18),
              label: const Text('Adjust Location'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryDark,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                side: const BorderSide(color: AppTheme.cardBorder),
              ),
            ),
            const SizedBox(height: 28),

            // Category Section
            const Text(
              'Category',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryDark,
              ),
            ),
            const SizedBox(height: 12),
            // Category Dropdown
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: DropdownButtonFormField<IncidentCategory>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: InputBorder.none,
                ),
                icon: const Icon(Icons.keyboard_arrow_down),
                isExpanded: true,
                items: IncidentCategory.values.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Row(
                      children: [
                        Icon(
                          _getCategoryIcon(category),
                          color: AppTheme.categoryColor(
                              _getCategoryLabel(category)),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _getCategoryLabel(category),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                  }
                },
                selectedItemBuilder: (context) {
                  return IncidentCategory.values.map((category) {
                    return Row(
                      children: [
                        Icon(
                          _getCategoryIcon(category),
                          color: _selectedCategory == category
                              ? AppTheme.categoryColor(
                                  _getCategoryLabel(category))
                              : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _getCategoryLabel(category),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: _selectedCategory == category
                                ? AppTheme.primaryDark
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    );
                  }).toList();
                },
              ),
            ),
            const SizedBox(height: 28),

            // Severity Level Section
            const Text(
              'Severity Level',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryDark,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: SeverityLevel.values.map((level) {
                final isSelected = _selectedSeverity == level;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedSeverity = level),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primaryRed
                                  : Colors.grey[400]!,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? Center(
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppTheme.primaryRed,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getSeverityLabel(level),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected
                                ? AppTheme.primaryDark
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),

            // Description Section
            const Text(
              'Description (Optional)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryDark,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Describe what you observed...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.primaryRed, width: 2),
                ),
                counterText: '',
              ),
            ),
            const SizedBox(height: 20),

            // Add Photo/Video Section
            GestureDetector(
              onTap: _pickMedia,
              child: Row(
                children: [
                  Icon(Icons.camera_alt, color: Colors.grey[600], size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Add Photo/Video',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            // Media preview
            if (_mediaFiles.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _mediaFiles.length,
                  itemBuilder: (context, index) {
                    final file = _mediaFiles[index];
                    final isVideo = file.path.endsWith('.mp4') ||
                        file.path.endsWith('.mov');
                    return Container(
                      width: 80,
                      height: 80,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (isVideo)
                            Container(
                              color: Colors.grey[200],
                              child: const Icon(
                                Icons.videocam,
                                size: 32,
                                color: Colors.grey,
                              ),
                            )
                          else
                            Image.file(
                              File(file.path),
                              fit: BoxFit.cover,
                            ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removeMedia(index),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: AppTheme.primaryRed,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Anonymous Toggle
            Row(
              children: [
                const Text(
                  'Report anonymously',
                  style: TextStyle(fontSize: 15),
                ),
                const Spacer(),
                Switch(
                  value: _isAnonymous,
                  activeColor: AppTheme.primaryRed,
                  onChanged: (v) => setState(() => _isAnonymous = v),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _submitting ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryRed,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Submit Report',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(IncidentCategory category) {
    switch (category) {
      case IncidentCategory.crime:
        return Icons.gavel;
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
    }
  }

  String _getCategoryLabel(IncidentCategory category) {
    switch (category) {
      case IncidentCategory.crime:
        return 'Crime';
      case IncidentCategory.infrastructure:
        return 'Infrastructure';
      case IncidentCategory.suspicious:
        return 'Suspicious Activity';
      case IncidentCategory.traffic:
        return 'Traffic Hazard';
      case IncidentCategory.environmental:
        return 'Environmental';
      case IncidentCategory.emergency:
        return 'Emergency';
    }
  }

  String _getSeverityLabel(SeverityLevel level) {
    switch (level) {
      case SeverityLevel.low:
        return 'Low';
      case SeverityLevel.moderate:
        return 'Moderate';
      case SeverityLevel.high:
        return 'High';
    }
  }
}

// Crosshairs painter for the map overlay
class _CrosshairsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[600]!
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw circle
    canvas.drawCircle(center, radius, paint);

    // Draw horizontal line
    canvas.drawLine(
      Offset(center.dx - radius * 0.7, center.dy),
      Offset(center.dx + radius * 0.7, center.dy),
      paint,
    );

    // Draw vertical line
    canvas.drawLine(
      Offset(center.dx, center.dy - radius * 0.7),
      Offset(center.dx, center.dy + radius * 0.7),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Location Picker Screen for manual location adjustment
class _LocationPickerScreen extends StatefulWidget {
  final LatLng initialLocation;

  const _LocationPickerScreen({required this.initialLocation});

  @override
  State<_LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<_LocationPickerScreen> {
  late LatLng _selectedLocation;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _selectedLocation),
            child: const Text(
              'Confirm',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedLocation,
              zoom: 17,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onCameraMove: (position) {
              _selectedLocation = position.target;
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
          ),
          // Center pin
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 40),
              child: Icon(
                Icons.location_on,
                color: AppTheme.primaryRed,
                size: 48,
              ),
            ),
          ),
          // Instructions
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'Move the map to position the pin at the incident location',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.primaryDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
