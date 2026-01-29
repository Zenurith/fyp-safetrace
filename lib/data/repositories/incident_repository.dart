import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/incident_model.dart';

class IncidentRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('incidents');

  Stream<List<IncidentModel>> getIncidentsStream() {
    return _collection
        .orderBy('reportedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => IncidentModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<List<IncidentModel>> getAll() async {
    final snapshot = await _collection
        .orderBy('reportedAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => IncidentModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<List<IncidentModel>> getByCategory(IncidentCategory category) async {
    final snapshot = await _collection
        .where('category', isEqualTo: category.index)
        .orderBy('reportedAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => IncidentModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<List<IncidentModel>> getRecent({Duration within = const Duration(hours: 24)}) async {
    final cutoff = DateTime.now().subtract(within);
    final snapshot = await _collection
        .where('reportedAt', isGreaterThan: cutoff.millisecondsSinceEpoch)
        .orderBy('reportedAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => IncidentModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<IncidentModel?> getById(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return IncidentModel.fromMap(doc.id, doc.data()!);
  }

  Future<void> add(IncidentModel incident) async {
    await _collection.doc(incident.id).set(incident.toMap());
  }

  Future<void> confirm(String id) async {
    await _collection.doc(id).update({
      'confirmations': FieldValue.increment(1),
    });
  }

  Future<void> delete(String id) async {
    await _collection.doc(id).delete();
  }
}
