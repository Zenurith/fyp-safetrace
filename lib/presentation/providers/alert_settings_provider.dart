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
        _repository.saveSettings(AlertSettingsModel.fromMap(map));
        notifyListeners();
      }
    } catch (_) {}
  }

  void updateRadius(double km) {
    _repository.saveSettings(settings.copyWith(radiusKm: km));
    _syncToFirestore();
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
    _syncToFirestore();
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
    _syncToFirestore();
    notifyListeners();
  }

  void toggleActiveHours(bool enabled) {
    _repository.saveSettings(settings.copyWith(activeHoursEnabled: enabled));
    _syncToFirestore();
    notifyListeners();
  }

  void updateActiveFrom(String time) {
    _repository.saveSettings(settings.copyWith(activeFrom: time));
    _syncToFirestore();
    notifyListeners();
  }

  void updateActiveTo(String time) {
    _repository.saveSettings(settings.copyWith(activeTo: time));
    _syncToFirestore();
    notifyListeners();
  }

  void toggleQuietHours(bool enabled) {
    _repository.saveSettings(settings.copyWith(quietHoursEnabled: enabled));
    _syncToFirestore();
    notifyListeners();
  }

  void updateQuietFrom(String time) {
    _repository.saveSettings(settings.copyWith(quietFrom: time));
    _syncToFirestore();
    notifyListeners();
  }

  void updateQuietTo(String time) {
    _repository.saveSettings(settings.copyWith(quietTo: time));
    _syncToFirestore();
    notifyListeners();
  }

  void saveSettings() {
    _syncToFirestore();
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
