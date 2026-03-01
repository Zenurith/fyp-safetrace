import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/comment_model.dart';

class CommentRepository {
  final _collection = FirebaseFirestore.instance.collection('comments');

  Stream<List<CommentModel>> watchByIncident(String incidentId) {
    return _collection
        .where('incidentId', isEqualTo: incidentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CommentModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<List<CommentModel>> getByIncident(String incidentId) async {
    final snapshot = await _collection
        .where('incidentId', isEqualTo: incidentId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => CommentModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<String> add(CommentModel comment) async {
    final docRef = await _collection.add(comment.toMap());
    return docRef.id;
  }

  Future<void> update(String id, String content) async {
    await _collection.doc(id).update({'content': content});
  }

  Future<void> delete(String id) async {
    await _collection.doc(id).delete();
  }

  Future<int> getCommentCount(String incidentId) async {
    final snapshot = await _collection
        .where('incidentId', isEqualTo: incidentId)
        .count()
        .get();
    return snapshot.count ?? 0;
  }
}
