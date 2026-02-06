import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/services/location_service.dart';
import '../../config/app_constants.dart';
import '../../utils/app_theme.dart';
import '../providers/community_provider.dart';
import '../providers/user_provider.dart';

class CreateCommunityScreen extends StatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _radiusController = TextEditingController(text: '2.0');
  final _locationService = LocationService();

  double _latitude = AppConstants.defaultLat;
  double _longitude = AppConstants.defaultLng;
  String _address = 'Detecting location...';
  bool _loadingLocation = false;
  bool _isSubmitting = false;
  bool _isPublic = true;

  @override
  void initState() {
    super.initState();
    _detectLocation();
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<CommunityProvider>();
    final userId = context.read<UserProvider>().currentUser?.id;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to create a community')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final communityId = await provider.createCommunity(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        creatorId: userId,
        latitude: _latitude,
        longitude: _longitude,
        radius: double.tryParse(_radiusController.text) ?? 2.0,
        address: _address,
        isPublic: _isPublic,
      );

      if (communityId != null && mounted) {
        await provider.loadMyCommunities(userId);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Community created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
        title: const Text('Create Community'),
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
                      color: const Color(0xFFE8F0FE),
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
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
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
                  Text(
                    'Members within this radius can be part of your community',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Visibility Toggle
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
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
                                _isPublic ? 'Public Community' : 'Private Community',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _isPublic
                                    ? 'Anyone can discover and request to join'
                                    : 'Only invited users can join',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isPublic,
                          activeColor: AppTheme.successGreen,
                          onChanged: (v) => setState(() => _isPublic = v),
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
                              : const Text('Create Community'),
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
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Creating community...'),
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
