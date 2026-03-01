import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/flag_model.dart';

class FlagRepository {
  final _collection = FirebaseFirestore.instance.collection('flags');

  Stream<List<FlagModel>> watchAll() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FlagModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<FlagModel>> watchPending() {
    return _collection
        .where('status', isEqualTo: FlagStatus.pending.index)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FlagModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<List<FlagModel>> getAll() async {
    final snapshot = await _collection
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => FlagModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<List<FlagModel>> getPending() async {
    final snapshot = await _collection
        .where('status', isEqualTo: FlagStatus.pending.index)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => FlagModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<String> add(FlagModel flag) async {
    final docRef = await _collection.add(flag.toMap());
    return docRef.id;
  }

  Future<void> updateStatus(
    String id,
    FlagStatus status, {
    String? resolvedBy,
    String? resolutionNote,
  }) async {
    await _collection.doc(id).update({
      'status': status.index,
      'resolvedAt': Timestamp.now(),
      'resolvedBy': resolvedBy,
      'resolutionNote': resolutionNote,
    });
  }

  Future<void> delete(String id) async {
    await _collection.doc(id).delete();
  }

  Future<int> getPendingCount() async {
    final snapshot = await _collection
        .where('status', isEqualTo: FlagStatus.pending.index)
        .count()
        .get();
    return snapshot.count ?? 0;
  }
}
