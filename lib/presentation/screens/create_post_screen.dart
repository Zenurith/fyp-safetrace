// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/app_constants.dart';
import '../../data/models/incident_model.dart';
import '../../data/services/location_service.dart';
import '../../data/services/media_upload_service.dart';
import '../../data/services/report_draft_service.dart';
import '../../data/services/category_suggestion_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/incident_enum_helpers.dart';
import '../providers/category_provider.dart';
import '../providers/incident_provider.dart';
import '../providers/user_provider.dart';
import '../providers/community_provider.dart';
import '../widgets/report/report_location_section.dart';
import '../widgets/report/community_selector_field.dart';
import '../widgets/report/report_category_grid.dart';
import '../widgets/report/report_severity_selector.dart';
import '../widgets/report/incident_time_picker_tile.dart';
import '../widgets/report/category_suggestion_banner.dart';
import '../widgets/report/report_media_section.dart';
import '../widgets/report/report_confirm_sheet.dart';
import 'full_screen_map_picker_screen.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _addressFocusNode = FocusNode();
  final _locationService = LocationService();
  final _mediaService = MediaUploadService();
  final _draftService = ReportDraftService();
  final _suggestionService = CategorySuggestionService(
    apiKey: AppConstants.geminiApiKey,
  );

  static const double _maxReportDistanceMeters = 5000;
  static const int _maxTitleLength = 100;
  static const int _maxDescriptionLength = 500;
  static const int _maxAddressLength = 300;
  static const int _maxMediaFiles = 5;

  IncidentCategory _selectedCategory = IncidentCategory.crime;
  String? _selectedCategoryName; // Non-null only for admin-created custom categories
  SeverityLevel _selectedSeverity = SeverityLevel.high;
  bool _isAnonymous = true;
  double _latitude = AppConstants.defaultLat;
  double _longitude = AppConstants.defaultLng;
  String _address = 'Jalan Genting Klang, Setapak';
  bool _loadingLocation = false;
  bool _isSubmitting = false;

  DateTime? _incidentTime;

  IncidentCategory? _suggestedCategory;
  bool _isSuggestingCategory = false;
  int _suggestionGeneration = 0;
  Timer? _suggestionDebounceTimer;
  Timer? _draftSaveTimer;

  double? _userCurrentLat;
  double? _userCurrentLng;
  bool _locationTooFar = false;

  String? _selectedCommunityId;

  List<PlaceSuggestion> _suggestions = [];
  Timer? _debounceTimer;
  bool _showSuggestions = false;

  GoogleMapController? _mapController;
  final List<XFile> _selectedMedia = [];

  ScaffoldMessengerState? _scaffoldMessenger;

  @override
  void initState() {
    super.initState();
    _addressController.addListener(_onAddressChanged);
    _addressFocusNode.addListener(_onAddressFocusChanged);
    _titleController.addListener(_onTextChangedForSuggestion);
    _titleController.addListener(_onTextChangedForDraft);
    _descriptionController.addListener(_onTextChangedForDraft);

    _detectLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<UserProvider>().currentUser?.id;
      if (userId != null) {
        context.read<CommunityProvider>().loadMyCommunities(userId);
      }
      _checkForDraft();
      // Force a server-side category refresh so any admin changes
      // (disabled/deleted categories) are reflected immediately.
      context.read<CategoryProvider>().refresh();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _suggestionDebounceTimer?.cancel();
    _draftSaveTimer?.cancel();
    _scaffoldMessenger?.clearSnackBars();
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _addressFocusNode.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ─── AI Category Suggestion (Gemini) ─────────────────────────────────────

  void _onTextChangedForSuggestion() {
    _suggestionDebounceTimer?.cancel();
    _suggestionDebounceTimer = Timer(const Duration(milliseconds: 800), () {
      _suggestCategory();
    });
  }

  Future<void> _suggestCategory() async {
    final title = _titleController.text.trim();
    if (title.length < 5) {
      if (mounted && (_suggestedCategory != null || _isSuggestingCategory)) {
        setState(() {
          _suggestedCategory = null;
          _isSuggestingCategory = false;
        });
      }
      return;
    }

    _suggestionGeneration++;
    final generation = _suggestionGeneration;
    if (mounted) setState(() => _isSuggestingCategory = true);

    final cat = await _suggestionService.suggestCategory(
      title,
      description: _descriptionController.text.trim(),
    );

    if (mounted && generation == _suggestionGeneration) {
      setState(() {
        _suggestedCategory = cat;
        _isSuggestingCategory = false;
      });
    }
  }

  // ─── Draft Auto-Save ──────────────────────────────────────────────────────

  void _onTextChangedForDraft() {
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(seconds: 1), () {
      _saveDraft();
    });
  }

  Future<void> _saveDraft() async {
    await _draftService.save(
      title: _titleController.text,
      description: _descriptionController.text,
      categoryIndex: _selectedCategory.index,
      severityIndex: _selectedSeverity.index,
      address: _address,
      latitude: _latitude,
      longitude: _longitude,
    );
  }

  Future<void> _checkForDraft() async {
    final draft = await _draftService.load();
    if (draft == null || !mounted) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Draft?'),
        content: const Text(
            'You have an unsaved draft. Would you like to restore it?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _draftService.clear();
            },
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (!mounted) return;
              setState(() {
                _titleController.text = draft.title;
                _descriptionController.text = draft.description;
                if (draft.categoryIndex < IncidentCategory.values.length) {
                  _selectedCategory =
                      IncidentCategory.values[draft.categoryIndex];
                }
                if (draft.severityIndex < SeverityLevel.values.length) {
                  _selectedSeverity =
                      SeverityLevel.values[draft.severityIndex];
                }
                if (draft.address.isNotEmpty) {
                  _address = draft.address;
                  _addressController.text = draft.address;
                }
                if (draft.latitude != null && draft.longitude != null) {
                  _latitude = draft.latitude!;
                  _longitude = draft.longitude!;
                }
              });
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.primaryRed),
            child: const Text('Restore'),
          ),
        ],
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

  // ─── Location ─────────────────────────────────────────────────────────────

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
        if (kDebugMode) debugPrint('Location detection returned null');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error detecting location: $e');
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

  Future<void> _openFullScreenMap() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenMapPickerScreen(
          initialPosition: LatLng(_latitude, _longitude),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
      });
      _mapController?.animateCamera(CameraUpdate.newLatLng(result));
      final addr = await _locationService.getAddressFromCoordinates(
          result.latitude, result.longitude);
      if (mounted) {
        setState(() {
          _address = addr;
          _addressController.text = addr;
        });
        _validateDistance();
      }
    }
  }

  double _calculateDistance() {
    if (_userCurrentLat == null || _userCurrentLng == null) return 0;
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
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  // ─── Incident Time ─────────────────────────────────────────────────────────

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

  // ─── Media ────────────────────────────────────────────────────────────────

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
                    color: AppTheme.primaryDark.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt,
                      color: AppTheme.primaryDark),
                ),
                title: const Text('Take Photo'),
                onTap: () async {
                  Navigator.pop(context);
                  if (_selectedMedia.length >= _maxMediaFiles) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              'Maximum $_maxMediaFiles files allowed.')));
                    }
                    return;
                  }
                  final image = await _mediaService.pickImage(
                      source: ImageSource.camera);
                  if (image != null && mounted) {
                    setState(() => _selectedMedia.add(image));
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryDark.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.videocam,
                      color: AppTheme.primaryDark),
                ),
                title: const Text('Record Video'),
                onTap: () async {
                  Navigator.pop(context);
                  if (_selectedMedia.length >= _maxMediaFiles) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              'Maximum $_maxMediaFiles files allowed.')));
                    }
                    return;
                  }
                  final video = await _mediaService.pickVideo(
                      source: ImageSource.camera);
                  if (video != null && mounted) {
                    setState(() => _selectedMedia.add(video));
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryDark.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library,
                      color: AppTheme.primaryDark),
                ),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  final images = await _mediaService.pickMultipleMedia();
                  if (!mounted) return;
                  if (images.isNotEmpty) {
                    final remaining = _maxMediaFiles - _selectedMedia.length;
                    final toAdd = images.take(remaining).toList();
                    final truncated = images.length > remaining;
                    setState(() => _selectedMedia.addAll(toAdd));
                    if (truncated) {
                      messenger.showSnackBar(SnackBar(
                        content: Text(
                          'Only $remaining more file(s) added. Maximum $_maxMediaFiles files allowed.',
                        ),
                      ));
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

  // ─── Submit Flow ──────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_selectedCommunityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a community to post this report.'),
          backgroundColor: AppTheme.primaryRed,
        ),
      );
      return;
    }
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
    await _showConfirmDialog();
  }

  Future<void> _showConfirmDialog() async {
    final addressToShow = _addressController.text.trim().isNotEmpty
        ? _addressController.text.trim()
        : _address;

    String? communityName;
    if (_selectedCommunityId != null) {
      final communities = context.read<CommunityProvider>().myCommunities;
      final match = communities.where((c) => c.id == _selectedCommunityId);
      if (match.isNotEmpty) communityName = match.first.name;
    }

    final confirmed = await showReportConfirmSheet(
      context: context,
      title: _titleController.text.trim(),
      category: _selectedCategory,
      severity: _selectedSeverity,
      address: addressToShow,
      incidentTime: _incidentTime,
      mediaCount: _selectedMedia.length,
      isAnonymous: _isAnonymous,
      communityName: communityName,
    );

    if (confirmed) _submitFinal();
  }

  Future<void> _submitFinal() async {
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
          content:
              Text('Title is too long (max $_maxTitleLength characters).'),
          backgroundColor: AppTheme.primaryRed,
        ),
      );
      return;
    }

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

    if (_userCurrentLat != null && _userCurrentLng != null) {
      final distance = _calculateDistance();
      if (distance > _maxReportDistanceMeters) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location is too far (${_formatDistance(distance)}). '
              'You can only report incidents within '
              '${_formatDistance(_maxReportDistanceMeters)} of your current location.',
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

    String? incidentId;
    try {
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
        communityIds:
            _selectedCommunityId != null ? [_selectedCommunityId!] : [],
        incidentTime: _incidentTime,
        customCategoryName: _selectedCategoryName,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          if (kDebugMode) debugPrint('Incident report timed out');
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

      if (_selectedMedia.isNotEmpty) {
        try {
          final mediaUrls = await _mediaService.uploadMultipleFiles(
              _selectedMedia, incidentId);
          if (mediaUrls.isNotEmpty) {
            await provider.updateIncidentMedia(incidentId, mediaUrls);
          }
        } catch (mediaError) {
          if (kDebugMode) debugPrint('Media upload failed: $mediaError');
        }
      }

      await _draftService.clear();
      if (!mounted) return;

      setState(() => _isSubmitting = false);
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.schedule, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('Report submitted for community review')),
            ],
          ),
          backgroundColor: AppTheme.warningOrange,
          duration: Duration(seconds: 3),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (kDebugMode) debugPrint('Submit error: $e');
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

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final myCommunities = context.watch<CommunityProvider>().myCommunities;

    return Scaffold(
      appBar: AppBar(title: const Text('Create a Post')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Location ──────────────────────────────────────────
                  ReportLocationSection(
                    latitude: _latitude,
                    longitude: _longitude,
                    addressController: _addressController,
                    addressFocusNode: _addressFocusNode,
                    loadingLocation: _loadingLocation,
                    locationTooFar: _locationTooFar,
                    userCurrentLat: _userCurrentLat,
                    userCurrentLng: _userCurrentLng,
                    suggestions: _suggestions,
                    showSuggestions: _showSuggestions,
                    formattedDistance: _userCurrentLat != null
                        ? _formatDistance(_calculateDistance())
                        : '',
                    onMapCreated: (c) => _mapController = c,
                    onMapTap: (latLng) {
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
                    onDetectLocation: _detectLocation,
                    onOpenFullScreenMap: _openFullScreenMap,
                    onSuggestionSelected: _selectSuggestion,
                    onClearAddress: () {
                      _addressController.clear();
                      setState(() {
                        _suggestions = [];
                        _showSuggestions = false;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Community ─────────────────────────────────────────
                  if (myCommunities.isEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.warningOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.warningOrange),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: AppTheme.warningOrange, size: 18),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'You must join a community before posting a report.',
                              style: TextStyle(
                                  fontSize: 13, color: AppTheme.warningOrange),
                            ),
                          ),
                        ],
                      ),
                    ),
                  CommunitySelectorField(
                    communities: myCommunities,
                    selectedCommunityId: _selectedCommunityId,
                    onCommunitySelected: (id) =>
                        setState(() => _selectedCommunityId = id),
                  ),
                  const SizedBox(height: 24),

                  // ── Category ──────────────────────────────────────────
                  const Text('Category',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ReportCategoryGrid(
                    selectedCategory: _selectedCategory,
                    selectedCategoryName: _selectedCategoryName,
                    onCategorySelected: (cat, customName) => setState(() {
                      _selectedCategory = cat;
                      _selectedCategoryName = customName;
                    }),
                  ),
                  const SizedBox(height: 24),

                  // ── Severity ──────────────────────────────────────────
                  const Text('Severity Level',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ReportSeveritySelector(
                    selectedSeverity: _selectedSeverity,
                    onSeverityChanged: (level) =>
                        setState(() => _selectedSeverity = level),
                  ),
                  const SizedBox(height: 24),

                  // ── Incident time ─────────────────────────────────────
                  const Text('When did this happen?',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  IncidentTimePickerTile(
                    incidentTime: _incidentTime,
                    onTap: _pickIncidentTime,
                    onClear: () => setState(() => _incidentTime = null),
                  ),
                  const SizedBox(height: 24),

                  // ── Title ─────────────────────────────────────────────
                  const Text('Title',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
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

                  // ── AI Suggestion Banner ──────────────────────────────
                  CategorySuggestionBanner(
                    suggestedCategory: _suggestedCategory,
                    selectedCategory: _selectedCategory,
                    isLoading: _isSuggestingCategory,
                    onApply: (cat) => setState(() {
                      _selectedCategory = cat;
                      _suggestedCategory = null;
                    }),
                    onDismiss: () =>
                        setState(() => _suggestedCategory = null),
                  ),
                  const SizedBox(height: 8),

                  // ── Description ───────────────────────────────────────
                  const Text('Description (Optional)',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
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

                  // ── Media ─────────────────────────────────────────────
                  const Text('Photo/Video Evidence',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ReportMediaSection(
                    selectedMedia: _selectedMedia,
                    maxMediaFiles: _maxMediaFiles,
                    onAddMedia: _pickMedia,
                    onRemoveMedia: _removeMedia,
                  ),
                  const SizedBox(height: 16),

                  // ── Anonymous toggle ──────────────────────────────────
                  Row(
                    children: [
                      const Text('Report anonymously',
                          style: TextStyle(fontSize: 15)),
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
                          onPressed: (_isSubmitting || _locationTooFar)
                              ? null
                              : _submit,
                          style: _locationTooFar
                              ? ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.textSecondary)
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
                        const Text('Submitting report...'),
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
