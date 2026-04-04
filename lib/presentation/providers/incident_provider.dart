import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models/incident_model.dart';
import '../../data/repositories/incident_repository.dart';
import '../../data/repositories/user_repository.dart';

class IncidentProvider extends ChangeNotifier {
  final IncidentRepository _repository = IncidentRepository();
  final UserRepository _userRepository = UserRepository();

  List<IncidentModel> _incidents = [];
  List<IncidentModel>? _filteredCache;
  List<IncidentModel> _myReports = [];
  bool _myReportsLoading = false;
  final Set<String> _activeFilters = {};
  final Set<SeverityLevel> _severityFilters = {};
  final Set<IncidentStatus> _statusFilters = {};
  DateTimeRange? _dateRange;
  IncidentModel? _selectedIncident;
  bool _mapTabRequested = false;
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _incidentsSubscription;
  StreamSubscription? _myReportsSubscription;
  List<IncidentModel> _communityIncidents = [];
  String? _activeCommunityId;
  StreamSubscription? _communitySubscription;
  List<IncidentModel> _pendingCommunityIncidents = [];
  StreamSubscription? _pendingCommunitySubscription;

  List<IncidentModel> get incidents {
    if (_filteredCache != null) return _filteredCache!;

    var list = _incidents;

    // Return all if no filters active
    if (_activeFilters.isEmpty &&
        _severityFilters.isEmpty &&
        _statusFilters.isEmpty &&
        _dateRange == null) {
      return _filteredCache = list;
    }

    return _filteredCache = list.where((i) {
      // Time filter
      if (_activeFilters.contains('Last 24 hours')) {
        final cutoff = DateTime.now().subtract(const Duration(hours: 24));
        if (i.reportedAt.isBefore(cutoff)) return false;
      }

      // Date range filter
      if (_dateRange != null) {
        if (i.reportedAt.isBefore(_dateRange!.start) ||
            i.reportedAt.isAfter(_dateRange!.end.add(const Duration(days: 1)))) {
          return false;
        }
      }

      // Category filters
      final categoryFilters =
          _activeFilters.where((f) => f != 'Last 24 hours').toSet();
      if (categoryFilters.isNotEmpty &&
          !categoryFilters.contains(i.categoryLabel)) {
        return false;
      }

      // Severity filters
      if (_severityFilters.isNotEmpty && !_severityFilters.contains(i.severity)) {
        return false;
      }

      // Status filters
      if (_statusFilters.isNotEmpty && !_statusFilters.contains(i.status)) {
        return false;
      }

      return true;
    }).toList();
  }

  /// Get all incidents unfiltered (for search)
  List<IncidentModel> get allIncidents => _incidents;

  List<IncidentModel> get myReports => _myReports;
  bool get myReportsLoading => _myReportsLoading;
  List<IncidentModel> get communityIncidents => _communityIncidents;
  List<IncidentModel> get pendingCommunityIncidents => _pendingCommunityIncidents;
  Set<String> get activeFilters => _activeFilters;
  Set<SeverityLevel> get severityFilters => _severityFilters;
  Set<IncidentStatus> get statusFilters => _statusFilters;
  DateTimeRange? get dateRange => _dateRange;
  IncidentModel? get selectedIncident => _selectedIncident;
  bool get mapTabRequested => _mapTabRequested;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get hasActiveFilters =>
      _activeFilters.isNotEmpty ||
      _severityFilters.isNotEmpty ||
      _statusFilters.isNotEmpty ||
      _dateRange != null;

  /// Start listening to recent incidents (last 7 days) - for map/main feed
  void startListening() {
    _incidentsSubscription?.cancel();
    _incidentsSubscription = _repository.watchAll().listen(
      (incidents) {
        _incidents = incidents;
        _filteredCache = null;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  /// Start listening to ALL incidents including old ones - for admin dashboard
  void startListeningAll() {
    _incidentsSubscription?.cancel();
    _incidentsSubscription = _repository.watchAllIncludingOld().listen(
      (incidents) {
        _incidents = incidents;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  void startListeningMyReports(String userId) {
    _myReportsSubscription?.cancel();
    _myReportsLoading = true;
    notifyListeners();
    _myReportsSubscription = _repository.watchByReporter(userId).listen(
      (reports) {
        _myReports = reports;
        _myReportsLoading = false;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _myReportsLoading = false;
        notifyListeners();
      },
    );
  }

  void watchCommunityIncidents(String communityId) {
    if (_activeCommunityId == communityId) return;
    _activeCommunityId = communityId;
    _communitySubscription?.cancel();
    _communityIncidents = [];
    notifyListeners();

    _communitySubscription = _repository.watchCommunityIncidents(communityId).listen(
      (incidents) {
        _communityIncidents = incidents;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  void watchPendingCommunityIncidents(String communityId) {
    _pendingCommunitySubscription?.cancel();
    _pendingCommunityIncidents = [];
    notifyListeners();

    _pendingCommunitySubscription =
        _repository.watchPendingCommunityIncidents(communityId).listen(
      (incidents) {
        _pendingCommunityIncidents = incidents;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  void stopWatchingCommunityIncidents() {
    _activeCommunityId = null;
    _communitySubscription?.cancel();
    _communityIncidents = [];
  }

  void stopWatchingPendingCommunityIncidents() {
    _pendingCommunitySubscription?.cancel();
    _pendingCommunityIncidents = [];
  }

  Future<bool> approveCommunityIncident(String id, String staffId) async {
    try {
      await _repository.updateStatus(
        id,
        IncidentStatus.underReview,
        updatedBy: staffId,
        note: 'Approved by community manager',
      );
      _pendingCommunityIncidents =
          _pendingCommunityIncidents.where((i) => i.id != id).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectCommunityIncident(String id, String staffId) async {
    try {
      await _repository.updateStatus(
        id,
        IncidentStatus.dismissed,
        updatedBy: staffId,
        note: 'Rejected by community manager',
      );
      _pendingCommunityIncidents =
          _pendingCommunityIncidents.where((i) => i.id != id).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _incidentsSubscription?.cancel();
    _myReportsSubscription?.cancel();
    _communitySubscription?.cancel();
    _pendingCommunitySubscription?.cancel();
    super.dispose();
  }

  Future<void> loadIncidents() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _incidents = await _repository.getAll();
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMyReports(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _myReports = await _repository.getByReporter(userId);
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  void toggleFilter(String filter) {
    if (_activeFilters.contains(filter)) {
      _activeFilters.remove(filter);
    } else {
      _activeFilters.add(filter);
    }
    _filteredCache = null;
    notifyListeners();
  }

  void toggleSeverityFilter(SeverityLevel severity) {
    if (_severityFilters.contains(severity)) {
      _severityFilters.remove(severity);
    } else {
      _severityFilters.add(severity);
    }
    _filteredCache = null;
    notifyListeners();
  }

  void toggleStatusFilter(IncidentStatus status) {
    if (_statusFilters.contains(status)) {
      _statusFilters.remove(status);
    } else {
      _statusFilters.add(status);
    }
    _filteredCache = null;
    notifyListeners();
  }

  void setDateRange(DateTimeRange? range) {
    _dateRange = range;
    // Remove 'Last 24 hours' if custom date range is set
    if (range != null) {
      _activeFilters.remove('Last 24 hours');
    }
    _filteredCache = null;
    notifyListeners();
  }

  void clearAllFilters() {
    _activeFilters.clear();
    _severityFilters.clear();
    _statusFilters.clear();
    _dateRange = null;
    _filteredCache = null;
    notifyListeners();
  }

  void selectIncident(IncidentModel? incident) {
    _selectedIncident = incident;
    notifyListeners();
  }

  void requestMapFocus(IncidentModel incident) {
    _selectedIncident = incident;
    _mapTabRequested = true;
    notifyListeners();
  }

  void acknowledgeMapTabRequest() {
    _mapTabRequested = false;
  }

  Future<String?> reportIncident({
    required String title,
    required IncidentCategory category,
    required SeverityLevel severity,
    required String description,
    required double latitude,
    required double longitude,
    required String address,
    required String reporterId,
    bool isAnonymous = false,
    List<String> mediaUrls = const [],
    bool? imageVerified,
    double? verificationScore,
    String? verificationNote,
    List<String> communityIds = const [],
    DateTime? incidentTime,
    String? customCategoryName,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Determine initial status based on AI verification result.
      // Image verification alone cannot set verified — that requires 2+ community upvotes.
      IncidentStatus initialStatus;
      if (imageVerified == true) {
        initialStatus = IncidentStatus.underReview; // Image passed → awaiting community votes
      } else {
        initialStatus = IncidentStatus.pending;     // Failed or unavailable
      }

      final incident = IncidentModel(
        id: '',
        title: title,
        category: category,
        severity: severity,
        description: description,
        latitude: latitude,
        longitude: longitude,
        address: address,
        reportedAt: DateTime.now(),
        reporterId: reporterId,
        isAnonymous: isAnonymous,
        mediaUrls: mediaUrls,
        status: initialStatus,
        imageVerified: imageVerified,
        verificationScore: verificationScore,
        verificationNote: verificationNote,
        communityIds: communityIds,
        incidentTime: incidentTime,
        customCategoryName: customCategoryName,
      );
      final id = await _repository.add(incident);

      // Award points and increment report count for the reporter
      await _userRepository.incrementReportCount(reporterId);

      _isLoading = false;
      notifyListeners();
      return id;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> updateIncidentMedia(String id, List<String> mediaUrls) async {
    try {
      await _repository.updateMediaUrls(id, mediaUrls);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> confirmIncident(String id) async {
    try {
      await _repository.confirm(id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteIncident(String id) async {
    // Optimistically remove from local lists for instant UI update
    _myReports = _myReports.where((i) => i.id != id).toList();
    _incidents = _incidents.where((i) => i.id != id).toList();
    if (_selectedIncident?.id == id) _selectedIncident = null;
    notifyListeners();

    try {
      await _repository.delete(id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Remove an incident from a community (community staff action).
  Future<bool> removeFromCommunity(String incidentId, String communityId) async {
    try {
      await _repository.removeFromCommunity(incidentId, communityId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> updateIncident(IncidentModel incident) async {
    try {
      await _repository.update(incident);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateIncidentStatus(
    String id,
    IncidentStatus status, {
    String? note,
  }) async {
    try {
      await _repository.updateStatus(id, status, note: note);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
