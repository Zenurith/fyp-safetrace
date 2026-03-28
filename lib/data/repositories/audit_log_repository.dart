import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/audit_log_model.dart';

class AuditLogRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('admin_audit_log');

  Future<void> create(AuditLogModel entry) async {
    await _collection.add(entry.toMap());
  }

  Stream<List<AuditLogModel>> watchAll() {
    return _collection
        .orderBy('timestamp', descending: true)
        .limit(200)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AuditLogModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<AuditLogModel>> watchByTargetType(String targetType) {
    return _collection
        .where('targetType', isEqualTo: targetType)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AuditLogModel.fromMap(doc.data(), doc.id))
            .toList());
  }
}
