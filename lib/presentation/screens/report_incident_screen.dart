// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/incident_model.dart';
import '../../data/models/image_verification_result.dart';
import '../../data/services/location_service.dart';
import '../../data/services/media_upload_service.dart';
import '../../data/services/image_verification_service.dart';
import '../../config/app_constants.dart';
import '../../utils/app_theme.dart';
import '../providers/incident_provider.dart';
import '../providers/user_provider.dart';
import '../providers/category_provider.dart';
import '../providers/community_provider.dart';

class ReportIncidentScreen extends StatefulWidget {
  const ReportIncidentScreen({super.key});

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _addressFocusNode = FocusNode();
  final _locationService = LocationService();
  final _mediaService = MediaUploadService();
  final _verificationService = ImageVerificationService(
    apiKey: AppConstants.geminiApiKey,
  );

  // Maximum allowed distance in meters (5 km)
  static const double _maxReportDistanceMeters = 5000;
  static const int _maxTitleLength = 100;
  static const int _maxDescriptionLength = 500;
  static const int _maxAddressLength = 300;
  static const int _maxMediaFiles = 5;

  IncidentCategory _selectedCategory = IncidentCategory.crime;
  SeverityLevel _selectedSeverity = SeverityLevel.high;
  bool _isAnonymous = true;
  double _latitude = AppConstants.defaultLat;
  double _longitude = AppConstants.defaultLng;
  String _address = 'Jalan Genting Klang, Setapak';
  bool _loadingLocation = false;
  bool _isSubmitting = false;
  bool _isVerifying = false;
  ImageVerificationResult? _verificationResult;

  // Enhancement 1: Incident time
  DateTime? _incidentTime;

  // Enhancement 5: AI category suggestion
  IncidentCategory? _suggestedCategory;
  Timer? _suggestionDebounceTimer;

  // Enhancement 6: Draft auto-save
  Timer? _draftSaveTimer;

  // User's actual current position (for distance validation)
  double? _userCurrentLat;
  double? _userCurrentLng;
  bool _locationTooFar = false;

  // Community sharing
  final Set<String> _selectedCommunityIds = {};

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

    // Enhancement 5: Listeners for AI category suggestion
    _titleController.addListener(_onTextChangedForSuggestion);
    _descriptionController.addListener(_onTextChangedForSuggestion);

    // Enhancement 6: Listeners for draft auto-save
    _titleController.addListener(_onTextChangedForDraft);
    _descriptionController.addListener(_onTextChangedForDraft);

    _detectLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<UserProvider>().currentUser?.id;
      if (userId != null) {
        context.read<CommunityProvider>().loadMyCommunities(userId);
      }
      _checkForDraft();
    });
  }

  // ─── Enhancement 5: AI Category Suggestion ───────────────────────────────

  void _onTextChangedForSuggestion() {
    _suggestionDebounceTimer?.cancel();
    _suggestionDebounceTimer = Timer(const Duration(milliseconds: 400), () {
      _suggestCategory();
    });
  }

  IncidentCategory? _matchCategoryFromText(String text) {
    final t = text.toLowerCase();
    const keywords = <IncidentCategory, List<String>>{
      IncidentCategory.emergency: [
        'fire', 'ambulance', 'medical', 'emergency', 'collapse', 'explosion',
        'earthquake', 'flood', 'rescue', 'unconscious', 'critical', 'faint',
        'injured', 'injure', 'hurt', 'bleeding', 'bleed', 'wound', 'fracture',
        'broken bone', 'heart attack', 'stroke', 'overdose', 'choking',
        'electrocuted', 'drowning', 'gas leak', 'trapped',
      ],
      IncidentCategory.crime: [
        'robbery', 'theft', 'steal', 'stolen', 'murder', 'assault', 'rape',
        'break in', 'break-in', 'vandalism', 'graffiti', 'shooting', 'stab',
        'drug', 'criminal', 'crime', 'burglary', 'snatch', 'pickpocket',
        'scam', 'fraud', 'kidnap', 'threaten', 'threat', 'weapon', 'gun',
        'knife', 'parang', 'punch', 'beat up', 'molest', 'harass', 'victim',
      ],
      IncidentCategory.traffic: [
        'accident', 'crash', 'collision', 'traffic', 'motorcycle', 'motorbike',
        'lorry', 'truck', 'jam', 'congestion', 'roadblock', 'pothole',
        'highway', 'vehicle', 'parking', 'car', 'bus', 'van', 'taxi',
        'road', 'reckless', 'speeding', 'drunk driving', 'hit and run',
      ],
      IncidentCategory.infrastructure: [
        'pipe', 'burst', 'electricity', 'power outage', 'blackout',
        'sewage', 'drain', 'lamppost', 'streetlight', 'pavement', 'sidewalk',
        'bridge', 'construction', 'infrastructure', 'broken', 'water supply',
        'no water', 'leaking', 'sinkhole', 'landslide', 'building',
      ],
      IncidentCategory.environmental: [
        'rubbish', 'garbage', 'litter', 'pollution', 'smoke', 'haze',
        'fallen tree', 'tree fell', 'environmental', 'dumping', 'illegal dump',
        'dead animal', 'pest', 'dengue', 'mosquito', 'rat', 'dirty',
        'stench', 'smell', 'river', 'toxic',
      ],
      IncidentCategory.suspicious: [
        'suspicious', 'stranger', 'loitering', 'following', 'watching',
        'unknown', 'weird', 'odd', 'lurking', 'stalking', 'spy', 'peeping',
        'abandoned', 'unattended', 'bag left', 'package',
      ],
    };

    for (final entry in keywords.entries) {
      for (final kw in entry.value) {
        if (t.contains(kw)) return entry.key;
      }
    }
    return null;
  }

  void _suggestCategory() {
    final text =
        '${_titleController.text.trim()} ${_descriptionController.text.trim()}';
    if (text.trim().length < 5) {
      if (mounted && _suggestedCategory != null) {
        setState(() => _suggestedCategory = null);
      }
      return;
    }
    final cat = _matchCategoryFromText(text);
    if (mounted) setState(() => _suggestedCategory = cat);
  }

  // ─── Enhancement 6: Draft Auto-Save ──────────────────────────────────────

  void _onTextChangedForDraft() {
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(seconds: 1), () {
      _saveDraft();
    });
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('report_draft_title', _titleController.text);
    await prefs.setString('report_draft_description', _descriptionController.text);
    await prefs.setInt('report_draft_category', _selectedCategory.index);
    await prefs.setInt('report_draft_severity', _selectedSeverity.index);
    await prefs.setString('report_draft_address', _address);
    await prefs.setDouble('report_draft_lat', _latitude);
    await prefs.setDouble('report_draft_lng', _longitude);
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('report_draft_title');
    await prefs.remove('report_draft_description');
    await prefs.remove('report_draft_category');
    await prefs.remove('report_draft_severity');
    await prefs.remove('report_draft_address');
    await prefs.remove('report_draft_lat');
    await prefs.remove('report_draft_lng');
  }

  Future<bool> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final title = prefs.getString('report_draft_title');
    if (title == null || title.isEmpty) return false;
    return true;
  }

  Future<void> _checkForDraft() async {
    final hasDraft = await _loadDraft();
    if (!hasDraft || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final draftTitle = prefs.getString('report_draft_title') ?? '';
    final draftDescription = prefs.getString('report_draft_description') ?? '';
    final draftCategoryIdx = prefs.getInt('report_draft_category');
    final draftSeverityIdx = prefs.getInt('report_draft_severity');
    final draftAddress = prefs.getString('report_draft_address') ?? '';
    final draftLat = prefs.getDouble('report_draft_lat');
    final draftLng = prefs.getDouble('report_draft_lng');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('You have an unsaved draft.'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Restore',
          onPressed: () {
            if (!mounted) return;
            setState(() {
              _titleController.text = draftTitle;
              _descriptionController.text = draftDescription;
              if (draftCategoryIdx != null &&
                  draftCategoryIdx < IncidentCategory.values.length) {
                _selectedCategory = IncidentCategory.values[draftCategoryIdx];
              }
              if (draftSeverityIdx != null &&
                  draftSeverityIdx < SeverityLevel.values.length) {
                _selectedSeverity = SeverityLevel.values[draftSeverityIdx];
              }
              if (draftAddress.isNotEmpty) {
                _address = draftAddress;
                _addressController.text = draftAddress;
              }
              if (draftLat != null && draftLng != null) {
                _latitude = draftLat;
                _longitude = draftLng;
              }
            });
          },
        ),
      ),
    );
  }

  // ─── Address Autocomplete ─────────────────────────────────────────────────

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

    final suggestions = await _locationService.getAddressSuggestions(
      query,
      latitude: _userCurrentLat,
      longitude: _userCurrentLng,
    );
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

    final coords =
        await _locationService.getCoordinatesFromPlaceId(suggestion.placeId);
    if (coords != null && mounted) {
      setState(() {
        _latitude = coords.latitude;
        _longitude = coords.longitude;
        _loadingLocation = false;
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(LatLng(coords.latitude, coords.longitude)),
      );
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
          _userCurrentLat = pos.latitude;
          _userCurrentLng = pos.longitude;
          _locationTooFar = false;
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)),
        );
      } else if (mounted) {
        debugPrint('Location detection returned null - check permissions');
      }
    } catch (e) {
      debugPrint('Error detecting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not detect your location. Please enter address manually.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
    if (mounted) setState(() => _loadingLocation = false);
  }

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

  void _validateDistance() {
    if (_userCurrentLat == null || _userCurrentLng == null) return;
    final distance = _calculateDistance();
    setState(() {
      _locationTooFar = distance > _maxReportDistanceMeters;
    });
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _suggestionDebounceTimer?.cancel();
    _draftSaveTimer?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _addressFocusNode.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ─── Enhancement 1: Incident Time Picker ─────────────────────────────────

  Future<void> _pickIncidentTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _incidentTime ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _incidentTime != null
          ? TimeOfDay.fromDateTime(_incidentTime!)
          : TimeOfDay.fromDateTime(now),
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _incidentTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  // ─── Media Picker ─────────────────────────────────────────────────────────

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
                  if (_selectedMedia.length >= _maxMediaFiles) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text('Maximum $_maxMediaFiles files allowed.')),
                      );
                    }
                    return;
                  }
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
                  child:
                      const Icon(Icons.videocam, color: AppTheme.accentBlue),
                ),
                title: const Text('Record Video'),
                onTap: () async {
                  Navigator.pop(context);
                  if (_selectedMedia.length >= _maxMediaFiles) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text('Maximum $_maxMediaFiles files allowed.')),
                      );
                    }
                    return;
                  }
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
                  child: const Icon(Icons.photo_library,
                      color: AppTheme.accentBlue),
                ),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  final images = await _mediaService.pickMultipleImages();
                  if (!mounted) return;
                  if (images.isNotEmpty) {
                    final remaining = _maxMediaFiles - _selectedMedia.length;
                    final toAdd = images.take(remaining).toList();
                    final truncated = images.length > remaining;
                    setState(() => _selectedMedia.addAll(toAdd));
                    if (truncated) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'Only $remaining more file(s) added. Maximum $_maxMediaFiles files allowed.',
                          ),
                        ),
                      );
                    }
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

  // ─── Enhancement 3 & 4: Submit Flow ──────────────────────────────────────

  /// New _submit() entry point: validates form, then shows confirm dialog.
  Future<void> _submit() async {
    // Enhancement 3: Inline form validation first
    final isValid = _formKey.currentState!.validate();
    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix the errors above.'),
          backgroundColor: AppTheme.primaryRed,
        ),
      );
      return;
    }

    // Enhancement 4: Show confirmation dialog before submitting
    await _showConfirmDialog();
  }

  /// Enhancement 4: Show bottom sheet summary before submitting.
  Future<void> _showConfirmDialog() async {
    final addressToShow = _addressController.text.trim().isNotEmpty
        ? _addressController.text.trim()
        : _address;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Confirm Report',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: AppTheme.fontFamily,
                    color: AppTheme.primaryDark,
                  ),
                ),
                const SizedBox(height: 16),
                // Title
                Text(
                  _titleController.text.trim(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: AppTheme.fontFamily,
                    color: AppTheme.primaryDark,
                  ),
                ),
                const SizedBox(height: 12),
                // Category chip
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text(
                        _categoryLabel(_selectedCategory),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontFamily: AppTheme.fontFamily,
                        ),
                      ),
                      backgroundColor:
                          AppTheme.categoryColor(_categoryLabel(_selectedCategory)),
                      padding: EdgeInsets.zero,
                    ),
                    Chip(
                      label: Text(
                        _severityLabel(_selectedSeverity),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontFamily: AppTheme.fontFamily,
                        ),
                      ),
                      backgroundColor: _severityColor(_selectedSeverity),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Location
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        addressToShow,
                        style: AppTheme.caption,
                      ),
                    ),
                  ],
                ),
                // Incident time
                if (_incidentTime != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.schedule,
                          size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        'When: ${DateFormat('dd MMM yyyy, h:mm a').format(_incidentTime!)}',
                        style: AppTheme.caption,
                      ),
                    ],
                  ),
                ],
                // Media count
                if (_selectedMedia.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.photo_library_outlined,
                          size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${_selectedMedia.length} media file(s) attached',
                        style: AppTheme.caption,
                      ),
                    ],
                  ),
                ],
                // Anonymous
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      _isAnonymous
                          ? Icons.visibility_off_outlined
                          : Icons.person_outline,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isAnonymous ? 'Submitted anonymously' : 'Submitted with your name',
                      style: AppTheme.caption,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _submitFinal();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryRed,
                        ),
                        child: const Text('Submit'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Enhancement 2 & 4: The actual submit logic (renamed from _submit).
  Future<void> _submitFinal() async {
    // Block banned or suspended users
    final currentUser = context.read<UserProvider>().currentUser;
    if (currentUser == null || !currentUser.canAccessApp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your account has been suspended or banned.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate title
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title for the incident.'),
          backgroundColor: AppTheme.primaryRed,
        ),
      );
      return;
    }
    if (title.length > _maxTitleLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Title is too long (max $_maxTitleLength characters).'),
          backgroundColor: AppTheme.primaryRed,
        ),
      );
      return;
    }

    // Validate description length
    final description = _descriptionController.text.trim();
    if (description.length > _maxDescriptionLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Description is too long (max $_maxDescriptionLength characters).'),
          backgroundColor: AppTheme.primaryRed,
        ),
      );
      return;
    }

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
    final userId =
        context.read<UserProvider>().currentUser?.id ?? 'anonymous';

    final addressToSubmit = _addressController.text.trim().isNotEmpty
        ? _addressController.text.trim()
        : _address;

    if (addressToSubmit.length > _maxAddressLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Address is too long (max $_maxAddressLength characters).'),
          backgroundColor: AppTheme.primaryRed,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    // Enhancement 2: Verify ALL selected images
    debugPrint(
        'Report: Media count=${_selectedMedia.length}, isConfigured=${_verificationService.isConfigured}');
    if (_selectedMedia.isNotEmpty && _verificationService.isConfigured) {
      debugPrint('Report: Starting image verification for all images...');
      setState(() => _isVerifying = true);

      try {
        ImageVerificationResult? worstResult;

        for (final media in _selectedMedia) {
          final ext = media.path.split('.').last.toLowerCase();
          final isVideo = ['mp4', 'mov', 'avi', 'mkv'].contains(ext);
          if (isVideo) continue; // Skip videos

          final imageBytes = await media.readAsBytes();
          debugPrint('Report: Read ${imageBytes.length} bytes from image');
          final result = await _verificationService.verifyImage(
            imageBytes: imageBytes,
            categoryName: _categoryLabel(_selectedCategory),
            description: _descriptionController.text.trim(),
          );

          // Keep the worst (lowest confidence) result
          if (worstResult == null ||
              result.confidenceScore < worstResult.confidenceScore) {
            worstResult = result;
          }
        }

        if (worstResult != null) {
          setState(() {
            _verificationResult = worstResult;
            _isVerifying = false;
          });

          if (!worstResult.isValid || worstResult.isLowConfidence) {
            if (mounted) {
              final shouldContinue =
                  await _showVerificationWarningDialog(worstResult);
              if (!shouldContinue) {
                setState(() => _isSubmitting = false);
                return;
              }
            }
          }
        } else {
          setState(() => _isVerifying = false);
        }
      } catch (e) {
        debugPrint('Image verification error: $e');
        setState(() => _isVerifying = false);
        // Continue with submission even if verification fails
      }
    }

    String? incidentId;

    try {
      // Create incident first to get the ID (with timeout)
      incidentId = await provider.reportIncident(
        title: _titleController.text.trim(),
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
        imageVerified: _verificationResult?.isValid,
        verificationScore: _verificationResult?.confidenceScore,
        verificationNote: _verificationResult?.explanation,
        communityIds: _selectedCommunityIds.toList(),
        incidentTime: _incidentTime,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('Incident report timed out');
          return null;
        },
      );

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
        debugPrint(
            'Report: Starting media upload for ${_selectedMedia.length} files');
        try {
          final mediaUrls = await _mediaService.uploadMultipleFiles(
            _selectedMedia,
            incidentId,
          );

          debugPrint('Report: Got ${mediaUrls.length} URLs back');
          if (mediaUrls.isNotEmpty) {
            debugPrint('Report: Updating incident with media URLs');
            await provider.updateIncidentMedia(incidentId, mediaUrls);
            debugPrint('Report: Media URLs updated successfully');
          } else {
            debugPrint(
                'Report: WARNING - No media URLs returned, skipping update');
          }
        } catch (mediaError) {
          debugPrint('Report: Media upload failed: $mediaError');
        }
      } else {
        debugPrint('Report: No media selected, skipping upload');
      }

      // Enhancement 6: Clear draft on successful submit
      await _clearDraft();

      if (!mounted) return;

      final wasAutoApproved = _verificationResult != null &&
          _verificationResult!.isValid &&
          _verificationResult!.isHighConfidence;

      setState(() => _isSubmitting = false);

      await Future.delayed(const Duration(milliseconds: 100));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                wasAutoApproved ? Icons.verified : Icons.schedule,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  wasAutoApproved
                      ? 'Report verified and published!'
                      : 'Report submitted for review',
                ),
              ),
            ],
          ),
          backgroundColor: wasAutoApproved
              ? AppTheme.successGreen
              : AppTheme.warningOrange,
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Submit error: $e');
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit report. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _showVerificationWarningDialog(
      ImageVerificationResult result) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  result.isValid ? Icons.warning_amber : Icons.error_outline,
                  color: result.isValid
                      ? AppTheme.warningOrange
                      : AppTheme.primaryRed,
                ),
                const SizedBox(width: 8),
                const Text('Image Verification'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.explanation,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Text('Confidence: '),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getConfidenceColor(result.confidenceScore),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${(result.confidenceScore * 100).toInt()}% (${result.confidenceLabel})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (result.concerns.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Concerns:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  ...result.concerns.map((c) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child:
                            Text('• $c', style: const TextStyle(fontSize: 13)),
                      )),
                ],
                const SizedBox(height: 16),
                Text(
                  result.isValid
                      ? 'The image may not clearly match your report. Do you want to submit anyway?'
                      : 'The image does not appear to match your selected category. Please review your submission.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Go Back'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: result.isValid
                      ? AppTheme.warningOrange
                      : AppTheme.primaryRed,
                ),
                child: const Text('Submit Anyway'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Color _getConfidenceColor(double score) {
    if (score >= 0.7) return AppTheme.successGreen;
    if (score >= 0.4) return AppTheme.warningOrange;
    return AppTheme.primaryRed;
  }

  // ─── Build ────────────────────────────────────────────────────────────────

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
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Location section ──────────────────────────────────
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
                              _locationService
                                  .getAddressFromCoordinates(
                                      latLng.latitude, latLng.longitude)
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
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Tap map to adjust location',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 11),
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
                                leading: const Icon(
                                    Icons.location_on_outlined,
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
                        onPressed:
                            _loadingLocation ? null : _detectLocation,
                        icon: const Icon(Icons.my_location, size: 16),
                        label: const Text('Use Current Location'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      if (_userCurrentLat != null &&
                          !_locationTooFar &&
                          !_loadingLocation) ...[
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
                  if (_locationTooFar)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color:
                                AppTheme.primaryRed.withValues(alpha: 0.3)),
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

                  // ── Category section ──────────────────────────────────
                  const Text(
                    'Category',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildCategoryGrid(),
                  const SizedBox(height: 24),

                  // ── Severity section ──────────────────────────────────
                  const Text(
                    'Severity Level',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: SeverityLevel.values.map((level) {
                      final selected = _selectedSeverity == level;
                      final color = _severityColor(level);
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedSeverity = level),
                        child: Column(
                          children: [
                            Container(
                              width: selected ? 56 : 44,
                              height: selected ? 56 : 44,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: selected
                                    ? Border.all(
                                        color: Colors.white, width: 3)
                                    : null,
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color:
                                              color.withValues(alpha: 0.5),
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
                                color: selected
                                    ? AppTheme.primaryDark
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // ── Enhancement 1: When did this happen ───────────────
                  const Text(
                    'When did this happen?',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _pickIncidentTime,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.cardBorder),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule,
                              color: AppTheme.primaryRed, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _incidentTime == null
                                      ? 'Just now'
                                      : DateFormat('dd MMM yyyy, h:mm a')
                                          .format(_incidentTime!),
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: _incidentTime == null
                                        ? AppTheme.textSecondary
                                        : AppTheme.primaryDark,
                                    fontFamily: AppTheme.fontFamily,
                                  ),
                                ),
                                if (_incidentTime != null)
                                  Text(
                                    'Tap to change',
                                    style: AppTheme.caption,
                                  ),
                              ],
                            ),
                          ),
                          if (_incidentTime != null)
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              color: AppTheme.textSecondary,
                              onPressed: () =>
                                  setState(() => _incidentTime = null),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Title ─────────────────────────────────────────────
                  const Text(
                    'Title',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleController,
                    maxLength: _maxTitleLength,
                    decoration: InputDecoration(
                      hintText: 'Brief title for the incident...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a title for the incident.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // ── AI Suggestion Banner ───────────────────────────────
                  if (_suggestedCategory != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _suggestedCategory == _selectedCategory
                            ? AppTheme.successGreen.withValues(alpha: 0.1)
                            : AppTheme.warningOrange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _suggestedCategory == _selectedCategory
                              ? AppTheme.successGreen.withValues(alpha: 0.4)
                              : AppTheme.warningOrange.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _suggestedCategory == _selectedCategory
                                ? Icons.check_circle_outline
                                : Icons.lightbulb_outline,
                            color: _suggestedCategory == _selectedCategory
                                ? AppTheme.successGreen
                                : AppTheme.warningOrange,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _suggestedCategory == _selectedCategory
                                  ? 'Category looks correct: ${_categoryLabel(_suggestedCategory!)}'
                                  : 'Suggested: ${_categoryLabel(_suggestedCategory!)}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.primaryDark,
                                fontFamily: AppTheme.fontFamily,
                              ),
                            ),
                          ),
                          if (_suggestedCategory != _selectedCategory)
                            TextButton(
                              onPressed: () => setState(() {
                                _selectedCategory = _suggestedCategory!;
                                _suggestedCategory = null;
                              }),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.warningOrange,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Apply',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            color: AppTheme.textSecondary,
                            onPressed: () =>
                                setState(() => _suggestedCategory = null),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),

                  // ── Description ───────────────────────────────────────
                  const Text(
                    'Description (Optional)',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    maxLength: _maxDescriptionLength,
                    decoration: InputDecoration(
                      hintText: 'Describe what you observed...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Media section ─────────────────────────────────────
                  const Text(
                    'Photo/Video Evidence',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
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

                  // ── Anonymous toggle ──────────────────────────────────
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
                        onChanged: (v) =>
                            setState(() => _isAnonymous = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Community sharing section ──────────────────────────
                  _buildCommunitySelector(),
                  const SizedBox(height: 24),

                  // ── Buttons ───────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              (_isSubmitting || _locationTooFar)
                                  ? null
                                  : _submit,
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
                              : Text(_locationTooFar
                                  ? 'Location Too Far'
                                  : 'Submit Report'),
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
                        Text(_isVerifying
                            ? 'Verifying image...'
                            : 'Submitting report...'),
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

  Widget _buildCommunitySelector() {
    final myCommunities = context.watch<CommunityProvider>().myCommunities;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Share to Communities',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Text(
              '(optional)',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Leave unselected to post publicly only.',
          style: AppTheme.caption,
        ),
        const SizedBox(height: 12),
        if (myCommunities.isEmpty)
          Text(
            'You are not a member of any community.',
            style: AppTheme.caption,
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: myCommunities.map((community) {
              final selected = _selectedCommunityIds.contains(community.id);
              return FilterChip(
                label: Text(community.name),
                selected: selected,
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _selectedCommunityIds.add(community.id);
                    } else {
                      _selectedCommunityIds.remove(community.id);
                    }
                  });
                },
                selectedColor: AppTheme.primaryRed.withValues(alpha: 0.15),
                checkmarkColor: AppTheme.primaryRed,
                labelStyle: TextStyle(
                  color: selected ? AppTheme.primaryRed : AppTheme.primaryDark,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                ),
                side: BorderSide(
                  color: selected ? AppTheme.primaryRed : AppTheme.cardBorder,
                ),
                backgroundColor: Colors.white,
                showCheckmark: true,
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildCategoryGrid() {
    final categoryProvider = context.watch<CategoryProvider>();
    final enabledCategories = categoryProvider.enabledCategories;

    final availableCategories = enabledCategories.where((cat) {
      return _getIncidentCategoryFromName(cat.name) != null;
    }).toList();

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
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
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
