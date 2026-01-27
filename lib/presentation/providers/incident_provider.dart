import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/incident_model.dart';
import '../../data/repositories/incident_repository.dart';

class IncidentProvider extends ChangeNotifier {
  final IncidentRepository _repository = IncidentRepository();
  final _uuid = const Uuid();

  final Set<String> _activeFilters = {};
  IncidentModel? _selectedIncident;

  List<IncidentModel> get incidents {
    var list = _repository.getAll();
    if (_activeFilters.isEmpty) return list;

    return list.where((i) {
      if (_activeFilters.contains('Last 24 hours')) {
        final cutoff = DateTime.now().subtract(const Duration(hours: 24));
        if (i.reportedAt.isBefore(cutoff)) return false;
      }
      if (_activeFilters.contains('Crime') &&
          !_activeFilters.contains(i.categoryLabel) &&
          i.category != IncidentCategory.crime) {
        // If Crime filter is active, only show crime when other categories aren't matching
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

  void reportIncident({
    required String title,
    required IncidentCategory category,
    required SeverityLevel severity,
    required String description,
    required double latitude,
    required double longitude,
    required String address,
    bool isAnonymous = false,
  }) {
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
    );
    _repository.add(incident);
    notifyListeners();
  }

  void confirmIncident(String id) {
    _repository.confirm(id);
    notifyListeners();
  }

  void deleteIncident(String id) {
    _repository.delete(id);
    notifyListeners();
  }
}
