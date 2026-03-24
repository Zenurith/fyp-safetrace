import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'system_config_repository.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  Future<void> createUser(String uid, String name, String handle) async {
    final user = UserModel(
      id: uid,
      name: name,
      handle: handle,
      memberSince: DateTime.now(),
    );
    await _usersCollection.doc(uid).set(user.toMap());
  }

  Future<UserModel?> getCurrentUser(String uid) async {
    final doc = await _usersCollection.doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  Future<void> updateUser(UserModel user) async {
    await _usersCollection.doc(user.id).update(user.toMap());
  }

  Future<List<UserModel>> getAllUsers() async {
    final snapshot = await _usersCollection.get();
    return snapshot.docs
        .map((doc) => UserModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> updateUserRole(String uid, String role) async {
    await _usersCollection.doc(uid).update({'role': role});
  }

  Future<void> updateProfilePhoto(String uid, String? photoUrl) async {
    await _usersCollection.doc(uid).update({'profilePhotoUrl': photoUrl});
  }

  Future<void> updateUserLocation(String uid, double latitude, double longitude) async {
    await _usersCollection.doc(uid).update({
      'lastLatitude': latitude,
      'lastLongitude': longitude,
      'timezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
    });
  }

  Future<void> updateAlertSettings(String uid, Map<String, dynamic> settings) async {
    await _usersCollection.doc(uid).update({'alertSettings': settings});
  }

  Future<Map<String, dynamic>?> getAlertSettings(String uid) async {
    final doc = await _usersCollection.doc(uid).get();
    return doc.data()?['alertSettings'] as Map<String, dynamic>?;
  }

  Future<void> updatePoints(String uid, int delta) async {
    await _usersCollection.doc(uid).update({
      'points': FieldValue.increment(delta),
    });
  }

  Future<void> incrementVoteCount(String uid) async {
    await _usersCollection.doc(uid).update({
      'votes': FieldValue.increment(1),
    });
  }

  /// Increment report count and award points when user creates a report
  Future<void> incrementReportCount(String uid) async {
    final doc = await _usersCollection.doc(uid).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final config = SystemConfigRepository.cached;
    final currentPoints = data['points'] ?? 0;
    final currentReports = data['reports'] ?? 0;
    final newPoints = currentPoints + config.pointsForReport;
    final newReports = currentReports + 1;

    await _usersCollection.doc(uid).update({
      'reports': newReports,
      'points': newPoints,
      'isTrusted': newPoints >= config.trustedThreshold,
    });
  }

  /// Recalculate trusted status based on current points
  Future<void> recalculateReputation(String uid) async {
    final doc = await _usersCollection.doc(uid).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final points = data['points'] ?? 0;
    final threshold = SystemConfigRepository.cached.trustedThreshold;

    await _usersCollection.doc(uid).update({
      'isTrusted': points >= threshold,
    });
  }

  /// Update points in one operation
  Future<void> updatePointsAndLevel(String uid, int pointsDelta) async {
    final doc = await _usersCollection.doc(uid).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final currentPoints = data['points'] ?? 0;
    final newPoints = (currentPoints + pointsDelta).clamp(0, double.infinity).toInt();
    final threshold = SystemConfigRepository.cached.trustedThreshold;

    await _usersCollection.doc(uid).update({
      'points': newPoints,
      'isTrusted': newPoints >= threshold,
    });
  }

  // Moderation methods
  Future<void> banUser(String uid, String reason) async {
    await _usersCollection.doc(uid).update({
      'isBanned': true,
      'banReason': reason,
    });
  }

  Future<void> unbanUser(String uid) async {
    await _usersCollection.doc(uid).update({
      'isBanned': false,
      'banReason': null,
    });
  }

  Future<void> suspendUser(String uid, DateTime until) async {
    await _usersCollection.doc(uid).update({
      'isSuspended': true,
      'suspendedUntil': until.millisecondsSinceEpoch,
    });
  }

  Future<void> unsuspendUser(String uid) async {
    await _usersCollection.doc(uid).update({
      'isSuspended': false,
      'suspendedUntil': null,
    });
  }

  Future<void> updateFcmToken(String uid, String? token) async {
    final data = <String, dynamic>{'fcmToken': token};
    if (token != null) {
      data['timezoneOffsetMinutes'] = DateTime.now().timeZoneOffset.inMinutes;
    }
    await _usersCollection.doc(uid).update(data);
  }

  Stream<List<UserModel>> watchAllUsers() {
    return _usersCollection
        .orderBy('memberSince', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromMap(doc.data(), doc.id))
            .toList());
  }
}
