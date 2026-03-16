import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/incident_model.dart';
import '../models/status_history_model.dart';

class IncidentRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Hide incidents older than 3 days
  static const int maxIncidentAgeDays = 3;

  CollectionReference<Map<String, dynamic>> get _incidentsCollection =>
      _firestore.collection('incidents');

  /// Watch recent incidents only (last 3 days) - for map and main feed
  Stream<List<IncidentModel>> watchAll() {
    final cutoff = DateTime.now().subtract(const Duration(days: maxIncidentAgeDays));
    return _incidentsCollection
        .where('reportedAt', isGreaterThan: Timestamp.fromDate(cutoff))
        .orderBy('reportedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => IncidentModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Watch all incidents including old ones - for admin dashboard
  Stream<List<IncidentModel>> watchAllIncludingOld() {
    return _incidentsCollection
        .orderBy('reportedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => IncidentModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<IncidentModel>> watchByReporter(String reporterId) {
    return _incidentsCollection
        .where('reporterId', isEqualTo: reporterId)
        .orderBy('reportedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => IncidentModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Get recent incidents only (last 3 days)
  Future<List<IncidentModel>> getAll() async {
    final cutoff = DateTime.now().subtract(const Duration(days: maxIncidentAgeDays));
    final snapshot = await _incidentsCollection
        .where('reportedAt', isGreaterThan: Timestamp.fromDate(cutoff))
        .orderBy('reportedAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => IncidentModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Get all incidents including old ones - for admin
  Future<List<IncidentModel>> getAllIncludingOld() async {
    final snapshot = await _incidentsCollection
        .orderBy('reportedAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => IncidentModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<List<IncidentModel>> getByReporter(String reporterId) async {
    final snapshot = await _incidentsCollection
        .where('reporterId', isEqualTo: reporterId)
        .orderBy('reportedAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => IncidentModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<List<IncidentModel>> getByCategory(IncidentCategory category) async {
    final snapshot = await _incidentsCollection
        .where('category', isEqualTo: category.index)
        .orderBy('reportedAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => IncidentModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<List<IncidentModel>> getRecent(
      {Duration within = const Duration(hours: 24)}) async {
    final cutoff = DateTime.now().subtract(within);
    final snapshot = await _incidentsCollection
        .where('reportedAt', isGreaterThan: Timestamp.fromDate(cutoff))
        .orderBy('reportedAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => IncidentModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<IncidentModel?> getById(String id) async {
    final doc = await _incidentsCollection.doc(id).get();
    if (doc.exists && doc.data() != null) {
      return IncidentModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  Future<String> add(IncidentModel incident) async {
    final docRef = await _incidentsCollection.add(incident.toMap());
    return docRef.id;
  }

  Future<void> update(IncidentModel incident) async {
    await _incidentsCollection.doc(incident.id).update(incident.toMap());
  }

  Future<void> delete(String id) async {
    await _incidentsCollection.doc(id).delete();
  }

  Future<void> confirm(String id) async {
    await _incidentsCollection.doc(id).update({
      'confirmations': FieldValue.increment(1),
    });
  }

  Future<void> updateStatus(
    String id,
    IncidentStatus status, {
    String? note,
    String? updatedBy,
  }) async {
    final historyEntry = StatusHistoryEntry(
      status: status,
      timestamp: DateTime.now(),
      updatedBy: updatedBy,
      note: note,
    );

    await _incidentsCollection.doc(id).update({
      'status': status.index,
      'statusUpdatedAt': Timestamp.now(),
      'statusNote': note,
      'statusHistory': FieldValue.arrayUnion([historyEntry.toMap()]),
    });
  }

  Future<void> updateMediaUrls(String id, List<String> mediaUrls) async {
    if (kDebugMode) debugPrint('IncidentRepository: Updating mediaUrls for $id: $mediaUrls');
    await _incidentsCollection.doc(id).update({
      'mediaUrls': mediaUrls,
    });
    if (kDebugMode) debugPrint('IncidentRepository: Firestore update complete');
  }
}
