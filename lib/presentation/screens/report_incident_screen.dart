// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../data/models/incident_model.dart';
import '../../data/services/location_service.dart';
import '../../data/services/media_upload_service.dart';
import '../../config/app_constants.dart';
import '../../utils/app_theme.dart';
import '../providers/incident_provider.dart';
import '../providers/user_provider.dart';

class ReportIncidentScreen extends StatefulWidget {
  const ReportIncidentScreen({super.key});

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final _descriptionController = TextEditingController();
  final _locationService = LocationService();
  final _mediaService = MediaUploadService();

  IncidentCategory _selectedCategory = IncidentCategory.crime;
  SeverityLevel _selectedSeverity = SeverityLevel.high;
  bool _isAnonymous = true;
  double _latitude = AppConstants.defaultLat;
  double _longitude = AppConstants.defaultLng;
  String _address = 'Jalan Genting Klang, Setapak';
  bool _loadingLocation = false;
  bool _isSubmitting = false;

  final List<XFile> _selectedMedia = [];

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
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingLocation = false);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
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
    final provider = context.read<IncidentProvider>();
    final userId = context.read<UserProvider>().currentUser?.id ?? 'anonymous';

    setState(() => _isSubmitting = true);

    try {
      // Create incident first to get the ID
      final incidentId = await provider.reportIncident(
        title: _selectedCategory.name,
        category: _selectedCategory,
        severity: _selectedSeverity,
        description: _descriptionController.text.trim().isEmpty
            ? 'No description provided.'
            : _descriptionController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        address: _address,
        reporterId: userId,
        isAnonymous: _isAnonymous,
      );

      if (incidentId != null && _selectedMedia.isNotEmpty) {
        // Upload media files
        final mediaUrls = await _mediaService.uploadMultipleFiles(
          _selectedMedia,
          incidentId,
        );

        // Update incident with media URLs
        if (mediaUrls.isNotEmpty) {
          await provider.updateIncidentMedia(incidentId, mediaUrls);
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incident reported successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
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
                Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.location_on,
                      size: 48,
                      color: AppTheme.primaryRed.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Automatically detected:',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                Text(
                  _loadingLocation ? 'Detecting location...' : _address,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _detectLocation,
                  icon: const Icon(Icons.location_on, size: 16),
                  label: const Text('Adjust Location'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Category section
                const Text(
                  'Category',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.1,
                  children: IncidentCategory.values.map((cat) {
                    final selected = _selectedCategory == cat;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat),
                      child: Container(
                        decoration: BoxDecoration(
                          color: selected ? Colors.white : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? AppTheme.primaryRed
                                : Colors.grey[300]!,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _categoryIcon(cat),
                              size: 32,
                              color: selected
                                  ? AppTheme.categoryColor(_categoryLabel(cat))
                                  : Colors.grey[600],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _categoryLabel(cat),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: selected
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
                        onPressed: _isSubmitting ? null : _submit,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Submit Report'),
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
