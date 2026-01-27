import 'package:flutter/foundation.dart';
import '../../data/models/alert_settings_model.dart';
import '../../data/models/incident_model.dart';
import '../../data/repositories/alert_repository.dart';

class AlertSettingsProvider extends ChangeNotifier {
  final AlertRepository _repository = AlertRepository();

  AlertSettingsModel get settings => _repository.getSettings();

  void updateRadius(double km) {
    _repository.saveSettings(settings.copyWith(radiusKm: km));
    notifyListeners();
  }

  void toggleSeverity(SeverityLevel level) {
    final current = Set<SeverityLevel>.from(settings.severityFilters);
    if (current.contains(level)) {
      current.remove(level);
    } else {
      current.add(level);
    }
    _repository.saveSettings(settings.copyWith(severityFilters: current));
    notifyListeners();
  }

  void toggleCategory(IncidentCategory category) {
    final current = Set<IncidentCategory>.from(settings.categoryFilters);
    if (current.contains(category)) {
      current.remove(category);
    } else {
      current.add(category);
    }
    _repository.saveSettings(settings.copyWith(categoryFilters: current));
    notifyListeners();
  }

  void toggleActiveHours(bool enabled) {
    _repository.saveSettings(settings.copyWith(activeHoursEnabled: enabled));
    notifyListeners();
  }

  void saveSettings() {
    // Already persisted via repository on each change
    notifyListeners();
  }
}
