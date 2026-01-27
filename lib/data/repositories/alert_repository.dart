import '../models/alert_settings_model.dart';

class AlertRepository {
  AlertSettingsModel _settings = AlertSettingsModel();

  AlertSettingsModel getSettings() => _settings;

  void saveSettings(AlertSettingsModel settings) {
    _settings = settings;
  }
}
