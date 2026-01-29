import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/incident_model.dart';
import '../../data/repositories/incident_repository.dart';

class IncidentProvider extends ChangeNotifier {
  final IncidentRepository _repository = IncidentRepository();
  final _uuid = const Uuid();

  List<IncidentModel> _incidents = [];
  final Set<String> _activeFilters = {};
  IncidentModel? _selectedIncident;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<List<IncidentModel>>? _subscription;

  IncidentProvider() {
    _subscribeToIncidents();
  }

  void _subscribeToIncidents() {
    _subscription = _repository.getIncidentsStream().listen(
      (incidents) {
        _incidents = incidents;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  List<IncidentModel> get incidents {
    var list = _incidents;
    if (_activeFilters.isEmpty) return list;

    return list.where((i) {
      if (_activeFilters.contains('Last 24 hours')) {
        final cutoff = DateTime.now().subtract(const Duration(hours: 24));
        if (i.reportedAt.isBefore(cutoff)) return false;
      }
      final categoryFilters = _activeFilters
          .where((f) => f != 'Last 24 hours')
          .toSet();
      if (categoryFilters.isNotEmpty &&
          !categoryFilters.contains(i.categoryLabel)) {
        return false;
      }
      return true;
    }).toList();
  }

  Set<String> get activeFilters => _activeFilters;
  IncidentModel? get selectedIncident => _selectedIncident;
  bool get isLoading => _isLoading;
  String? get error => _error;

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

  Future<void> reportIncident({
    required String title,
    required IncidentCategory category,
    required SeverityLevel severity,
    required String description,
    required double latitude,
    required double longitude,
    required String address,
    bool isAnonymous = false,
    List<String> mediaUrls = const [],
  }) async {
    final incident = IncidentModel(
      id: _uuid.v4(),
      title: title,
      category: category,
      severity: severity,
      description: description,
      latitude: latitude,
      longitude: longitude,
      address: address,
      reportedAt: DateTime.now(),
      reporterId: 'currentUser',
      isAnonymous: isAnonymous,
      mediaUrls: mediaUrls,
    );
    await _repository.add(incident);
  }

  Future<void> confirmIncident(String id) async {
    await _repository.confirm(id);
  }

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    // Stream will automatically update
  }
}
