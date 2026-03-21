import 'package:shared_preferences/shared_preferences.dart';

class ReportDraft {
  final String title;
  final String description;
  final String address;
  final int categoryIndex;
  final int severityIndex;
  final double? latitude;
  final double? longitude;

  const ReportDraft({
    required this.title,
    required this.description,
    required this.address,
    required this.categoryIndex,
    required this.severityIndex,
    this.latitude,
    this.longitude,
  });
}

class ReportDraftService {
  static const _keyTitle = 'report_draft_title';
  static const _keyDescription = 'report_draft_description';
  static const _keyCategory = 'report_draft_category';
  static const _keySeverity = 'report_draft_severity';
  static const _keyAddress = 'report_draft_address';
  static const _keyLat = 'report_draft_lat';
  static const _keyLng = 'report_draft_lng';

  Future<void> save({
    required String title,
    required String description,
    required int categoryIndex,
    required int severityIndex,
    required String address,
    double? latitude,
    double? longitude,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTitle, title);
    await prefs.setString(_keyDescription, description);
    await prefs.setInt(_keyCategory, categoryIndex);
    await prefs.setInt(_keySeverity, severityIndex);
    await prefs.setString(_keyAddress, address);
    if (latitude != null) await prefs.setDouble(_keyLat, latitude);
    if (longitude != null) await prefs.setDouble(_keyLng, longitude);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyTitle);
    await prefs.remove(_keyDescription);
    await prefs.remove(_keyCategory);
    await prefs.remove(_keySeverity);
    await prefs.remove(_keyAddress);
    await prefs.remove(_keyLat);
    await prefs.remove(_keyLng);
  }

  Future<ReportDraft?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final title = prefs.getString(_keyTitle);
    if (title == null || title.isEmpty) return null;

    return ReportDraft(
      title: title,
      description: prefs.getString(_keyDescription) ?? '',
      address: prefs.getString(_keyAddress) ?? '',
      categoryIndex: prefs.getInt(_keyCategory) ?? 0,
      severityIndex: prefs.getInt(_keySeverity) ?? 0,
      latitude: prefs.getDouble(_keyLat),
      longitude: prefs.getDouble(_keyLng),
    );
  }
}
