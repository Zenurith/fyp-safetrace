import '../models/incident_model.dart';

class IncidentRepository {
  final List<IncidentModel> _incidents = [];

  IncidentRepository() {
    _seedDemoData();
  }

  void _seedDemoData() {
    _incidents.addAll([
      IncidentModel(
        id: '1',
        title: 'Theft',
        category: IncidentCategory.crime,
        severity: SeverityLevel.high,
        description:
            'Phone snatching incident reported by witness. Two suspects on motorcycle. Proceed with caution in this area.',
        latitude: 3.1920,
        longitude: 101.7180,
        address: 'Jalan Genting Klang, near Setapak Central Mall',
        reportedAt: DateTime.now().subtract(const Duration(hours: 2)),
        reporterId: 'user1',
        confirmations: 5,
      ),
      IncidentModel(
        id: '2',
        title: 'Road Accident',
        category: IncidentCategory.traffic,
        severity: SeverityLevel.high,
        description: 'Multi-vehicle collision causing traffic congestion.',
        latitude: 3.1880,
        longitude: 101.7260,
        address: 'KL East Mall, Setapak',
        reportedAt: DateTime.now().subtract(const Duration(hours: 1)),
        reporterId: 'user2',
        confirmations: 3,
      ),
      IncidentModel(
        id: '3',
        title: 'Broken Street Light',
        category: IncidentCategory.infrastructure,
        severity: SeverityLevel.low,
        description: 'Street light not functioning, area is dark at night.',
        latitude: 3.1840,
        longitude: 101.7140,
        address: 'M3 Shopping Mall area',
        reportedAt: DateTime.now().subtract(const Duration(hours: 5)),
        reporterId: 'user3',
        confirmations: 2,
      ),
      IncidentModel(
        id: '4',
        title: 'Suspicious Person',
        category: IncidentCategory.suspicious,
        severity: SeverityLevel.moderate,
        description:
            'Unknown individual loitering near residential area. Residents advised to be vigilant.',
        latitude: 3.1800,
        longitude: 101.7300,
        address: 'Wangsa Maju area',
        reportedAt: DateTime.now().subtract(const Duration(hours: 3)),
        reporterId: 'user1',
        confirmations: 4,
      ),
      IncidentModel(
        id: '5',
        title: 'Flash Flood',
        category: IncidentCategory.environmental,
        severity: SeverityLevel.high,
        description:
            'Low-lying area experiencing flash flooding. Avoid driving through.',
        latitude: 3.1770,
        longitude: 101.7220,
        address: 'Danau Kota',
        reportedAt: DateTime.now().subtract(const Duration(minutes: 45)),
        reporterId: 'user4',
        confirmations: 8,
      ),
    ]);
  }

  List<IncidentModel> getAll() => List.unmodifiable(_incidents);

  List<IncidentModel> getByCategory(IncidentCategory category) {
    return _incidents.where((i) => i.category == category).toList();
  }

  List<IncidentModel> getRecent({Duration within = const Duration(hours: 24)}) {
    final cutoff = DateTime.now().subtract(within);
    return _incidents.where((i) => i.reportedAt.isAfter(cutoff)).toList();
  }

  IncidentModel? getById(String id) {
    try {
      return _incidents.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  void add(IncidentModel incident) {
    _incidents.insert(0, incident);
  }

  void confirm(String id) {
    final index = _incidents.indexWhere((i) => i.id == id);
    if (index != -1) {
      _incidents[index] = _incidents[index].copyWith(
        confirmations: _incidents[index].confirmations + 1,
      );
    }
  }
}
