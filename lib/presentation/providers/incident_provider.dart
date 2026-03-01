import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models/incident_model.dart';
import '../../data/repositories/incident_repository.dart';
import '../../data/repositories/user_repository.dart';

class IncidentProvider extends ChangeNotifier {
  final IncidentRepository _repository = IncidentRepository();
  final UserRepository _userRepository = UserRepository();

  List<IncidentModel> _incidents = [];
  List<IncidentModel> _myReports = [];
  final Set<String> _activeFilters = {};
  final Set<SeverityLevel> _severityFilters = {};
  final Set<IncidentStatus> _statusFilters = {};
  DateTimeRange? _dateRange;
  IncidentModel? _selectedIncident;
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _incidentsSubscription;
  StreamSubscription? _myReportsSubscription;

  List<IncidentModel> get incidents {
    var list = _incidents;

    // Return all if no filters active
    if (_activeFilters.isEmpty &&
        _severityFilters.isEmpty &&
        _statusFilters.isEmpty &&
        _dateRange == null) {
      return list;
    }

    return list.where((i) {
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
  Set<String> get activeFilters => _activeFilters;
  Set<SeverityLevel> get severityFilters => _severityFilters;
  Set<IncidentStatus> get statusFilters => _statusFilters;
  DateTimeRange? get dateRange => _dateRange;
  IncidentModel? get selectedIncident => _selectedIncident;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get hasActiveFilters =>
      _activeFilters.isNotEmpty ||
      _severityFilters.isNotEmpty ||
      _statusFilters.isNotEmpty ||
      _dateRange != null;

  void startListening() {
    _incidentsSubscription?.cancel();
    _incidentsSubscription = _repository.watchAll().listen(
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
    _myReportsSubscription = _repository.watchByReporter(userId).listen(
      (reports) {
        _myReports = reports;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _incidentsSubscription?.cancel();
    _myReportsSubscription?.cancel();
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
    notifyListeners();
  }

  void toggleSeverityFilter(SeverityLevel severity) {
    if (_severityFilters.contains(severity)) {
      _severityFilters.remove(severity);
    } else {
      _severityFilters.add(severity);
    }
    notifyListeners();
  }

  void toggleStatusFilter(IncidentStatus status) {
    if (_statusFilters.contains(status)) {
      _statusFilters.remove(status);
    } else {
      _statusFilters.add(status);
    }
    notifyListeners();
  }

  void setDateRange(DateTimeRange? range) {
    _dateRange = range;
    // Remove 'Last 24 hours' if custom date range is set
    if (range != null) {
      _activeFilters.remove('Last 24 hours');
    }
    notifyListeners();
  }

  void clearAllFilters() {
    _activeFilters.clear();
    _severityFilters.clear();
    _statusFilters.clear();
    _dateRange = null;
    notifyListeners();
  }

  void selectIncident(IncidentModel? incident) {
    _selectedIncident = incident;
    notifyListeners();
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
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
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
        status: IncidentStatus.pending,
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
    try {
      await _repository.delete(id);
      if (_selectedIncident?.id == id) {
        _selectedIncident = null;
      }
      notifyListeners();
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
