import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/incident_model.dart';
import '../../data/repositories/incident_repository.dart';

class IncidentProvider extends ChangeNotifier {
  final IncidentRepository _repository = IncidentRepository();

  List<IncidentModel> _incidents = [];
  List<IncidentModel> _myReports = [];
  final Set<String> _activeFilters = {};
  IncidentModel? _selectedIncident;
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _incidentsSubscription;
  StreamSubscription? _myReportsSubscription;

  List<IncidentModel> get incidents {
    var list = _incidents;
    if (_activeFilters.isEmpty) return list;

    return list.where((i) {
      if (_activeFilters.contains('Last 24 hours')) {
        final cutoff = DateTime.now().subtract(const Duration(hours: 24));
        if (i.reportedAt.isBefore(cutoff)) return false;
      }
      final categoryFilters =
          _activeFilters.where((f) => f != 'Last 24 hours').toSet();
      if (categoryFilters.isNotEmpty &&
          !categoryFilters.contains(i.categoryLabel)) {
        return false;
      }
      return true;
    }).toList();
  }

  List<IncidentModel> get myReports => _myReports;
  Set<String> get activeFilters => _activeFilters;
  IncidentModel? get selectedIncident => _selectedIncident;
  bool get isLoading => _isLoading;
  String? get error => _error;

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
