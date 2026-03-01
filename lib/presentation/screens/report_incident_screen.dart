// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../data/models/incident_model.dart';
import '../../data/models/category_model.dart';
import '../../data/services/location_service.dart';
import '../../data/services/media_upload_service.dart';
import '../../config/app_constants.dart';
import '../../utils/app_theme.dart';
import '../providers/incident_provider.dart';
import '../providers/user_provider.dart';
import '../providers/category_provider.dart';

class ReportIncidentScreen extends StatefulWidget {
  const ReportIncidentScreen({super.key});

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _addressFocusNode = FocusNode();
  final _locationService = LocationService();
  final _mediaService = MediaUploadService();

  // Maximum allowed distance in meters (5 km)
  static const double _maxReportDistanceMeters = 5000;

  IncidentCategory _selectedCategory = IncidentCategory.crime;
  SeverityLevel _selectedSeverity = SeverityLevel.high;
  bool _isAnonymous = true;
  double _latitude = AppConstants.defaultLat;
  double _longitude = AppConstants.defaultLng;
  String _address = 'Jalan Genting Klang, Setapak';
  bool _loadingLocation = false;
  bool _isSubmitting = false;

  // User's actual current position (for distance validation)
  double? _userCurrentLat;
  double? _userCurrentLng;
  bool _locationTooFar = false;

  // Address autocomplete state
  List<PlaceSuggestion> _suggestions = [];
  Timer? _debounceTimer;
  bool _showSuggestions = false;

  // Map controller
  GoogleMapController? _mapController;

  final List<XFile> _selectedMedia = [];

  @override
  void initState() {
    super.initState();
    _addressController.addListener(_onAddressChanged);
    _addressFocusNode.addListener(_onAddressFocusChanged);
    _detectLocation();
  }

  void _onAddressChanged() {
    if (!_addressFocusNode.hasFocus) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _fetchSuggestions(_addressController.text);
    });
  }

  void _onAddressFocusChanged() {
    if (!_addressFocusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_addressFocusNode.hasFocus) {
          setState(() => _showSuggestions = false);
        }
      });
    }
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.length < 3) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    final suggestions = await _locationService.getAddressSuggestions(query);
    if (mounted) {
      setState(() {
        _suggestions = suggestions;
        _showSuggestions = suggestions.isNotEmpty;
      });
    }
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    setState(() {
      _showSuggestions = false;
      _loadingLocation = true;
    });
    _addressController.text = suggestion.description;
    _address = suggestion.description;
    _addressFocusNode.unfocus();

    final coords = await _locationService.getCoordinatesFromPlaceId(suggestion.placeId);
    if (coords != null && mounted) {
      setState(() {
        _latitude = coords.latitude;
        _longitude = coords.longitude;
        _loadingLocation = false;
      });
      // Animate map to selected location
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(LatLng(coords.latitude, coords.longitude)),
      );
      // Validate distance after selecting address
      _validateDistance();
    } else {
      setState(() => _loadingLocation = false);
    }
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
          _addressController.text = addr;
          // Store user's actual current position for distance validation
          _userCurrentLat = pos.latitude;
          _userCurrentLng = pos.longitude;
          _locationTooFar = false;
        });
        // Animate map to new location
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)),
        );
      } else if (mounted) {
        // Location returned null - could be permissions issue
        debugPrint('Location detection returned null - check permissions');
      }
    } catch (e) {
      debugPrint('Error detecting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not detect your location. Please enter address manually.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
    if (mounted) setState(() => _loadingLocation = false);
  }

  /// Calculate distance between user's current location and selected incident location
  double _calculateDistance() {
    if (_userCurrentLat == null || _userCurrentLng == null) {
      return 0;
    }
    return Geolocator.distanceBetween(
      _userCurrentLat!,
      _userCurrentLng!,
      _latitude,
      _longitude,
    );
  }

  /// Check if the selected location is within allowed radius
  void _validateDistance() {
    if (_userCurrentLat == null || _userCurrentLng == null) return;

    final distance = _calculateDistance();
    setState(() {
      _locationTooFar = distance > _maxReportDistanceMeters;
    });
  }

  /// Format distance for display
  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _descriptionController.dispose();
    _addressController.dispose();
    _addressFocusNode.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt, color: AppTheme.accentBlue),
                ),
                title: const Text('Take Photo'),
                onTap: () async {
                  Navigator.pop(context);
                  final image = await _mediaService.pickImage(
                    source: ImageSource.camera,
                  );
                  if (image != null && mounted) {
                    setState(() => _selectedMedia.add(image));
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.videocam, color: AppTheme.accentBlue),
                ),
                title: const Text('Record Video'),
                onTap: () async {
                  Navigator.pop(context);
                  final video = await _mediaService.pickVideo(
                    source: ImageSource.camera,
                  );
                  if (video != null && mounted) {
                    setState(() => _selectedMedia.add(video));
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library, color: AppTheme.accentBlue),
                ),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final images = await _mediaService.pickMultipleImages();
                  if (images.isNotEmpty && mounted) {
                    setState(() => _selectedMedia.addAll(images));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeMedia(int index) {
    setState(() => _selectedMedia.removeAt(index));
  }

  Future<void> _submit() async {
    // Validate distance before submission
    if (_userCurrentLat != null && _userCurrentLng != null) {
      final distance = _calculateDistance();
      if (distance > _maxReportDistanceMeters) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location is too far (${_formatDistance(distance)}). '
              'You can only report incidents within ${_formatDistance(_maxReportDistanceMeters)} of your current location.',
            ),
            backgroundColor: AppTheme.primaryRed,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    final provider = context.read<IncidentProvider>();
    final userId = context.read<UserProvider>().currentUser?.id ?? 'anonymous';

    // Use address from controller if available, otherwise use detected address
    final addressToSubmit = _addressController.text.trim().isNotEmpty
        ? _addressController.text.trim()
        : _address;

    setState(() => _isSubmitting = true);

    String? incidentId;

    try {
      // Create incident first to get the ID (with timeout)
      incidentId = await provider.reportIncident(
        title: _selectedCategory.name,
        category: _selectedCategory,
        severity: _selectedSeverity,
        description: _descriptionController.text.trim().isEmpty
            ? 'No description provided.'
            : _descriptionController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        address: addressToSubmit,
        reporterId: userId,
        isAnonymous: _isAnonymous,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('Incident report timed out');
          return null;
        },
      );

      // Check if incident was created successfully
      if (incidentId == null) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to create incident. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Upload media if any
      if (_selectedMedia.isNotEmpty) {
        try {
          final mediaUrls = await _mediaService.uploadMultipleFiles(
            _selectedMedia,
            incidentId,
          );

          if (mediaUrls.isNotEmpty) {
            await provider.updateIncidentMedia(incidentId, mediaUrls);
          }
        } catch (mediaError) {
          // Media upload failed, but incident was created - still consider it a success
          debugPrint('Media upload failed: $mediaError');
        }
      }

      // Success - pop the screen
      if (!mounted) return;

      // First disable loading, then pop
      setState(() => _isSubmitting = false);

      // Small delay to ensure state is updated
      await Future.delayed(const Duration(milliseconds: 100));

      if (!mounted) return;

      Navigator.of(context).pop(true); // Pass true to indicate success

    } catch (e) {
      debugPrint('Submit error: $e');
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Incident'),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location section
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
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 180,
                    child: Stack(
                      children: [
                        GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(_latitude, _longitude),
                            zoom: 15,
                          ),
                          onMapCreated: (controller) {
                            _mapController = controller;
                          },
                          markers: {
                            Marker(
                              markerId: const MarkerId('incident_location'),
                              position: LatLng(_latitude, _longitude),
                              icon: BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueRed,
                              ),
                            ),
                          },
                          onTap: (latLng) {
                            setState(() {
                              _latitude = latLng.latitude;
                              _longitude = latLng.longitude;
                            });
                            // Reverse geocode to get address
                            _locationService
                                .getAddressFromCoordinates(latLng.latitude, latLng.longitude)
                                .then((addr) {
                              if (mounted) {
                                setState(() {
                                  _address = addr;
                                  _addressController.text = addr;
                                });
                                _validateDistance();
                              }
                            });
                          },
                          zoomControlsEnabled: false,
                          myLocationEnabled: true,
                          myLocationButtonEnabled: false,
                        ),
                        if (_loadingLocation)
                          Container(
                            color: Colors.white.withValues(alpha: 0.7),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        // Tap hint
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Address input with autocomplete
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _addressController,
                      focusNode: _addressFocusNode,
                      decoration: InputDecoration(
                        labelText: 'Address',
                        hintText: 'Type to search address...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _addressController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _addressController.clear();
                                  setState(() {
                                    _suggestions = [];
                                    _showSuggestions = false;
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          _address = value;
                          setState(() => _showSuggestions = false);
                        }
                      },
                    ),
                    if (_showSuggestions && _suggestions.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        constraints: const BoxConstraints(maxHeight: 200),
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
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _suggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = _suggestions[index];
                            return ListTile(
                              leading: const Icon(Icons.location_on_outlined,
                                  color: AppTheme.primaryRed),
                              title: Text(
                                suggestion.description,
                                style: const TextStyle(fontSize: 14),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _selectSuggestion(suggestion),
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
                      onPressed: _loadingLocation ? null : _detectLocation,
                      icon: const Icon(Icons.my_location, size: 16),
                      label: const Text('Use Current Location'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    if (_userCurrentLat != null && !_locationTooFar && !_loadingLocation) ...[
                      const SizedBox(width: 8),
                      Text(
                        _formatDistance(_calculateDistance()),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
                // Warning if location is too far
                if (_locationTooFar)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: AppTheme.primaryRed, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Location is ${_formatDistance(_calculateDistance())} away. '
                            'You can only report incidents within ${_formatDistance(_maxReportDistanceMeters)} of your current location.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // Category section
                const Text(
                  'Category',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildCategoryGrid(),
                const SizedBox(height: 24),

                // Severity section
                const Text(
                  'Severity Level',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: SeverityLevel.values.map((level) {
                    final selected = _selectedSeverity == level;
                    final color = _severityColor(level);
                    return GestureDetector(
                      onTap: () => setState(() => _selectedSeverity = level),
                      child: Column(
                        children: [
                          Container(
                            width: selected ? 56 : 44,
                            height: selected ? 56 : 44,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: selected
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.5),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      )
                                    ]
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _severityLabel(level),
                            style: TextStyle(
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: selected ? AppTheme.primaryDark : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Description
                const Text(
                  'Description (Optional)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Describe what you observed...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Media section
                const Text(
                  'Photo/Video Evidence',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_selectedMedia.isNotEmpty) ...[
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedMedia.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _selectedMedia.length) {
                          return _buildAddMediaButton();
                        }
                        return _buildMediaPreview(index);
                      },
                    ),
                  ),
                ] else ...[
                  GestureDetector(
                    onTap: _pickMedia,
                    child: Container(
                      width: double.infinity,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo,
                              size: 32, color: Colors.grey[600]),
                          const SizedBox(height: 8),
                          Text(
                            'Add Photo/Video',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Anonymous toggle
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
                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (_isSubmitting || _locationTooFar) ? null : _submit,
                        style: _locationTooFar
                            ? ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey,
                              )
                            : null,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_locationTooFar ? 'Location Too Far' : 'Submit Report'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          if (_isSubmitting)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Submitting report...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMediaPreview(int index) {
    final file = _selectedMedia[index];
    final isVideo = ['mp4', 'mov', 'avi', 'mkv']
        .contains(file.path.split('.').last.toLowerCase());

    return Container(
      width: 100,
      height: 100,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: isVideo
            ? null
            : DecorationImage(
                image: FileImage(File(file.path)),
                fit: BoxFit.cover,
              ),
        color: isVideo ? Colors.grey[800] : null,
      ),
      child: Stack(
        children: [
          if (isVideo)
            const Center(
              child: Icon(Icons.videocam, color: Colors.white, size: 32),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removeMedia(index),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddMediaButton() {
    return GestureDetector(
      onTap: _pickMedia,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Icon(Icons.add, size: 32, color: Colors.grey),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    final categoryProvider = context.watch<CategoryProvider>();
    final enabledCategories = categoryProvider.enabledCategories;

    // Filter to only show categories that have a matching IncidentCategory enum
    final availableCategories = enabledCategories.where((cat) {
      return _getIncidentCategoryFromName(cat.name) != null;
    }).toList();

    // If no enabled categories from provider, fall back to all enum values
    if (availableCategories.isEmpty) {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.1,
        children: IncidentCategory.values.map((cat) {
          final selected = _selectedCategory == cat;
          return _buildCategoryItem(
            label: _categoryLabel(cat),
            icon: _categoryIcon(cat),
            color: AppTheme.categoryColor(_categoryLabel(cat)),
            selected: selected,
            onTap: () => setState(() => _selectedCategory = cat),
          );
        }).toList(),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.1,
      children: availableCategories.map((cat) {
        final incidentCat = _getIncidentCategoryFromName(cat.name);
        if (incidentCat == null) return const SizedBox.shrink();

        final selected = _selectedCategory == incidentCat;
        return _buildCategoryItem(
          label: cat.name,
          icon: cat.icon,
          color: cat.color,
          selected: selected,
          onTap: () => setState(() => _selectedCategory = incidentCat),
        );
      }).toList(),
    );
  }

  Widget _buildCategoryItem({
    required String label,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.primaryRed : Colors.grey[300]!,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: selected ? color : Colors.grey[600],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? AppTheme.primaryDark : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  IncidentCategory? _getIncidentCategoryFromName(String name) {
    switch (name.toLowerCase()) {
      case 'crime':
        return IncidentCategory.crime;
      case 'infrastructure':
        return IncidentCategory.infrastructure;
      case 'suspicious':
        return IncidentCategory.suspicious;
      case 'traffic':
        return IncidentCategory.traffic;
      case 'environmental':
        return IncidentCategory.environmental;
      case 'emergency':
        return IncidentCategory.emergency;
      default:
        return null;
    }
  }

  IconData _categoryIcon(IncidentCategory cat) {
    switch (cat) {
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
    }
  }

  String _categoryLabel(IncidentCategory cat) {
    switch (cat) {
      case IncidentCategory.crime:
        return 'Crime';
      case IncidentCategory.infrastructure:
        return 'Infrastructure';
      case IncidentCategory.suspicious:
        return 'Suspicious';
      case IncidentCategory.traffic:
        return 'Traffic';
      case IncidentCategory.environmental:
        return 'Environmental';
      case IncidentCategory.emergency:
        return 'Emergency';
    }
  }

  String _severityLabel(SeverityLevel level) {
    switch (level) {
      case SeverityLevel.low:
        return 'Low';
      case SeverityLevel.moderate:
        return 'Moderate';
      case SeverityLevel.high:
        return 'High';
    }
  }

  Color _severityColor(SeverityLevel level) {
    switch (level) {
      case SeverityLevel.low:
        return AppTheme.severityLow;
      case SeverityLevel.moderate:
        return AppTheme.severityModerate;
      case SeverityLevel.high:
        return AppTheme.severityHigh;
    }
  }
}
