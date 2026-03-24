import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/system_config_model.dart';

class SystemConfigRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Static cache — updated by SystemConfigProvider's stream.
  /// Lets VoteRepository / UserRepository read config values synchronously
  /// without a Firestore round-trip on every action.
  static SystemConfigModel _cached = SystemConfigModel.defaults;
  static SystemConfigModel get cached => _cached;
  static void updateCache(SystemConfigModel config) => _cached = config;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection('system_config').doc('app_settings');

  Stream<SystemConfigModel> watch() {
    return _doc.snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return SystemConfigModel.defaults;
      return SystemConfigModel.fromMap(snap.data()!);
    });
  }

  Future<SystemConfigModel> get() async {
    final snap = await _doc.get();
    if (!snap.exists || snap.data() == null) return SystemConfigModel.defaults;
    return SystemConfigModel.fromMap(snap.data()!);
  }

  Future<void> save(SystemConfigModel config, String updatedBy) async {
    final updated = config.copyWith(
      updatedAt: DateTime.now(),
      updatedBy: updatedBy,
    );
    await _doc.set(updated.toMap(), SetOptions(merge: true));
  }

  Future<void> updateFields(
      Map<String, dynamic> fields, String updatedBy) async {
    await _doc.set(
      {
        ...fields,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
        'updatedBy': updatedBy,
      },
      SetOptions(merge: true),
    );
  }
}
