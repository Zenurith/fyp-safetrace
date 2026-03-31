import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../data/models/community_model.dart';
import '../../data/services/location_service.dart';
import '../../data/services/media_upload_service.dart';
import '../../config/app_constants.dart';
import '../../utils/app_theme.dart';
import '../providers/community_provider.dart';
import '../providers/user_provider.dart';

class CreateCommunityScreen extends StatefulWidget {
  final CommunityModel? communityToEdit;

  const CreateCommunityScreen({super.key, this.communityToEdit});

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _radiusController = TextEditingController(text: '2.0');
  final _locationService = LocationService();
  final _mediaUploadService = MediaUploadService();

  double _latitude = AppConstants.defaultLat;
  double _longitude = AppConstants.defaultLng;
  String _address = 'Detecting location...';
  bool _loadingLocation = false;
  bool _isSubmitting = false;
  bool _isPublic = true;
  bool _requiresApproval = false;

  XFile? _pickedImageFile;
  Uint8List? _pickedImageBytes;
  String? _existingImageUrl;

  bool get _isEditMode => widget.communityToEdit != null;

  @override
  void initState() {
    super.initState();
    final c = widget.communityToEdit;
    if (c != null) {
      _nameController.text = c.name;
      _descriptionController.text = c.description;
      _radiusController.text = c.radius.toString();
      _latitude = c.latitude;
      _longitude = c.longitude;
      _address = c.address;
      _isPublic = c.isPublic;
      _requiresApproval = c.requiresApproval;
      _existingImageUrl = c.imageUrl;
    } else {
      _detectLocation();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _radiusController.dispose();
    super.dispose();
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
    } catch (_) {
      if (mounted) {
        setState(() => _address = 'Could not detect location');
      }
    }
    if (mounted) setState(() => _loadingLocation = false);
  }

  Future<void> _pickImage() async {
    final file = await _mediaUploadService.pickImage();
    if (file != null && mounted) {
      final bytes = await file.readAsBytes();
      setState(() {
        _pickedImageFile = file;
        _pickedImageBytes = bytes;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<CommunityProvider>();
    final userId = context.read<UserProvider>().currentUser?.id;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (userId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('You must be logged in')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? imageUrl = _existingImageUrl;
      if (_pickedImageFile != null) {
        final tempId = 'community_${DateTime.now().millisecondsSinceEpoch}';
        imageUrl = await _mediaUploadService.uploadCommunityImage(
            tempId, _pickedImageFile!);
      }

      if (_isEditMode) {
        final updated = widget.communityToEdit!.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          radius: double.tryParse(_radiusController.text) ??
              widget.communityToEdit!.radius,
          isPublic: _isPublic,
          requiresApproval: _requiresApproval,
          imageUrl: imageUrl,
        );
        final success = await provider.updateCommunity(updated);
        if (mounted) {
          if (success) {
            navigator.pop();
            messenger.showSnackBar(
              const SnackBar(content: Text('Community updated!')),
            );
          } else {
            messenger.showSnackBar(
              SnackBar(content: Text(provider.error ?? 'Failed to update')),
            );
          }
        }
      } else {
        final communityId = await provider.createCommunity(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          creatorId: userId,
          latitude: _latitude,
          longitude: _longitude,
          radius: double.tryParse(_radiusController.text) ?? 2.0,
          address: _address,
          isPublic: _isPublic,
          requiresApproval: _requiresApproval,
          imageUrl: imageUrl,
        );
        if (communityId != null && mounted) {
          await provider.loadMyCommunities(userId);
          navigator.pop();
          messenger.showSnackBar(
            const SnackBar(content: Text('Community created successfully!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Community' : 'Create Community'),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Community image picker
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _isSubmitting ? null : _pickImage,
                          child: CircleAvatar(
                            radius: 44,
                            backgroundColor: AppTheme.backgroundGrey,
                            backgroundImage: _pickedImageBytes != null
                                ? MemoryImage(_pickedImageBytes!)
                                    as ImageProvider
                                : (_existingImageUrl != null
                                    ? NetworkImage(_existingImageUrl!)
                                    : null),
                            child: (_pickedImageBytes == null &&
                                    _existingImageUrl == null)
                                ? const Icon(
                                    Icons.add_a_photo,
                                    color: AppTheme.textSecondary,
                                    size: 32,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tap to ${(_pickedImageBytes != null || _existingImageUrl != null) ? 'change' : 'add'} community photo',
                          style: AppTheme.caption,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Community Name
                  const Text(
                    'Community Name',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: 'e.g., Taman Melati Neighborhood Watch',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.group),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a community name';
                      }
                      if (value.trim().length < 3) {
                        return 'Name must be at least 3 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Description
                  const Text(
                    'Description',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Describe your community and its purpose...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a description';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Location Section
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
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundGrey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 48,
                          color: AppTheme.primaryRed.withValues(alpha: 0.7),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _loadingLocation ? 'Detecting location...' : _address,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (!_loadingLocation) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${_latitude.toStringAsFixed(4)}, ${_longitude.toStringAsFixed(4)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!_isEditMode) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _loadingLocation ? null : _detectLocation,
                      icon: const Icon(Icons.my_location, size: 16),
                      label: const Text('Update Location'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Coverage Radius
                  const Text(
                    'Coverage Radius (km)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _radiusController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: 'e.g., 2.0',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.radar),
                      suffixText: 'km',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a radius';
                      }
                      final radius = double.tryParse(value);
                      if (radius == null || radius <= 0) {
                        return 'Please enter a valid radius';
                      }
                      if (radius > 50) {
                        return 'Radius cannot exceed 50 km';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Members within this radius can be part of your community',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Visibility Toggle
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundGrey,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isPublic ? Icons.public : Icons.lock,
                          color: _isPublic
                              ? AppTheme.successGreen
                              : AppTheme.warningOrange,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isPublic
                                    ? 'Public Community'
                                    : 'Private Community',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _isPublic
                                    ? 'Anyone can discover and request to join'
                                    : 'Anyone can request — admin must approve',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isPublic,
                          activeTrackColor: AppTheme.successGreen,
                          onChanged: (v) => setState(() {
                            _isPublic = v;
                            _requiresApproval = !v;
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              _isSubmitting ? null : () => Navigator.pop(context),
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
                              : Text(_isEditMode
                                  ? 'Save Changes'
                                  : 'Create Community'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          if (_isSubmitting)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(_isEditMode
                            ? 'Saving changes...'
                            : 'Creating community...'),
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
}
