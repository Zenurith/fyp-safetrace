import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/alert_settings_model.dart';
import '../../data/models/incident_model.dart';
import '../../data/repositories/alert_repository.dart';
import '../../data/repositories/user_repository.dart';

class AlertSettingsProvider extends ChangeNotifier {
  final AlertRepository _repository = AlertRepository();
  final UserRepository _userRepository = UserRepository();

  String? _userId;
  Timer? _debounceTimer;
  AlertSettingsModel _committed = AlertSettingsModel();

  AlertSettingsModel get settings => _repository.getSettings();

  Future<void> setUserId(String uid) async {
    if (_userId == uid) return;
    _userId = uid;
    await _loadFromFirestore();
  }

  Future<void> _loadFromFirestore() async {
    if (_userId == null) return;
    try {
      final map = await _userRepository.getAlertSettings(_userId!);
      if (map != null) {
        final loaded = AlertSettingsModel.fromMap(map);
        _committed = loaded;
        _repository.saveSettings(loaded);
        notifyListeners();
      }
    } catch (_) {}
  }

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

  void updateActiveFrom(String time) {
    _repository.saveSettings(settings.copyWith(activeFrom: time));
    notifyListeners();
  }

  void updateActiveTo(String time) {
    _repository.saveSettings(settings.copyWith(activeTo: time));
    notifyListeners();
  }

  void toggleQuietHours(bool enabled) {
    _repository.saveSettings(settings.copyWith(quietHoursEnabled: enabled));
    notifyListeners();
  }

  void updateQuietFrom(String time) {
    _repository.saveSettings(settings.copyWith(quietFrom: time));
    notifyListeners();
  }

  void updateQuietTo(String time) {
    _repository.saveSettings(settings.copyWith(quietTo: time));
    notifyListeners();
  }

  void saveSettings() {
    _committed = settings;
    _syncToFirestore();
    notifyListeners();
  }

  /// Reverts any unsaved changes back to the last saved state.
  void discardChanges() {
    _repository.saveSettings(_committed);
    notifyListeners();
  }

  void _syncToFirestore() {
    if (_userId == null) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      _userRepository.updateAlertSettings(_userId!, settings.toMap());
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
