import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_safetrace/data/models/incident_model.dart';

void main() {
  test('IncidentModel timeAgo returns correct format', () {
    final incident = IncidentModel(
      id: '1',
      title: 'Test',
      category: IncidentCategory.crime,
      severity: SeverityLevel.high,
      description: 'Test incident',
      latitude: 3.0,
      longitude: 101.0,
      address: 'Test address',
      reportedAt: DateTime.now().subtract(const Duration(hours: 2)),
      reporterId: 'user1',
    );
    expect(incident.timeAgo, '2 hours ago');
  });

  test('IncidentModel categoryLabel returns correct string', () {
    final incident = IncidentModel(
      id: '1',
      title: 'Test',
      category: IncidentCategory.traffic,
      severity: SeverityLevel.low,
      description: 'Test',
      latitude: 3.0,
      longitude: 101.0,
      address: 'Test',
      reportedAt: DateTime.now(),
      reporterId: 'user1',
    );
    expect(incident.categoryLabel, 'Traffic');
    expect(incident.severityLabel, 'Low');
  });
}
