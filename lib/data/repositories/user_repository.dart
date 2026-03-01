import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  // Level thresholds and titles
  static const List<int> _levelThresholds = [0, 100, 300, 600, 1000, 1500, 2500, 4000, 6000, 10000];
  static const List<String> _levelTitles = [
    'Newcomer',      // Level 1: 0-99
    'Observer',      // Level 2: 100-299
    'Reporter',      // Level 3: 300-599
    'Contributor',   // Level 4: 600-999
    'Guardian',      // Level 5: 1000-1499
    'Protector',     // Level 6: 1500-2499
    'Sentinel',      // Level 7: 2500-3999
    'Champion',      // Level 8: 4000-5999
    'Hero',          // Level 9: 6000-9999
    'Legend',        // Level 10: 10000+
  ];

  // Points awarded for actions
  static const int pointsForReport = 10;
  static const int pointsForUpvoteReceived = 5;
  static const int pointsForDownvoteReceived = -3;
  static const int trustedThreshold = 500; // Points needed to become trusted

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
    final currentPoints = data['points'] ?? 0;
    final currentReports = data['reports'] ?? 0;
    final newPoints = currentPoints + pointsForReport;
    final newReports = currentReports + 1;

    // Calculate new level based on points
    final levelData = _calculateLevel(newPoints);

    await _usersCollection.doc(uid).update({
      'reports': newReports,
      'points': newPoints,
      'level': levelData['level'],
      'levelTitle': levelData['title'],
      'isTrusted': newPoints >= trustedThreshold,
    });
  }

  /// Recalculate level and trusted status based on current points
  Future<void> recalculateReputation(String uid) async {
    final doc = await _usersCollection.doc(uid).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final points = data['points'] ?? 0;
    final levelData = _calculateLevel(points);

    await _usersCollection.doc(uid).update({
      'level': levelData['level'],
      'levelTitle': levelData['title'],
      'isTrusted': points >= trustedThreshold,
    });
  }

  /// Update points and recalculate level in one operation
  Future<void> updatePointsAndLevel(String uid, int pointsDelta) async {
    final doc = await _usersCollection.doc(uid).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final currentPoints = data['points'] ?? 0;
    final newPoints = (currentPoints + pointsDelta).clamp(0, double.infinity).toInt();
    final levelData = _calculateLevel(newPoints);

    await _usersCollection.doc(uid).update({
      'points': newPoints,
      'level': levelData['level'],
      'levelTitle': levelData['title'],
      'isTrusted': newPoints >= trustedThreshold,
    });
  }

  /// Calculate level and title based on points
  Map<String, dynamic> _calculateLevel(int points) {
    int level = 1;
    String title = _levelTitles[0];

    for (int i = _levelThresholds.length - 1; i >= 0; i--) {
      if (points >= _levelThresholds[i]) {
        level = i + 1;
        title = i < _levelTitles.length ? _levelTitles[i] : _levelTitles.last;
        break;
      }
    }

    return {'level': level, 'title': title};
  }

  /// Get user's current level info
  static Map<String, dynamic> getLevelInfo(int points) {
    int level = 1;
    String title = _levelTitles[0];
    int nextThreshold = _levelThresholds[1];
    int prevThreshold = 0;

    for (int i = _levelThresholds.length - 1; i >= 0; i--) {
      if (points >= _levelThresholds[i]) {
        level = i + 1;
        title = i < _levelTitles.length ? _levelTitles[i] : _levelTitles.last;
        prevThreshold = _levelThresholds[i];
        nextThreshold = i + 1 < _levelThresholds.length
            ? _levelThresholds[i + 1]
            : _levelThresholds[i];
        break;
      }
    }

    return {
      'level': level,
      'title': title,
      'pointsToNext': nextThreshold - points,
      'progress': level >= _levelThresholds.length
          ? 1.0
          : (points - prevThreshold) / (nextThreshold - prevThreshold),
    };
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
    await _usersCollection.doc(uid).update({
      'fcmToken': token,
    });
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
