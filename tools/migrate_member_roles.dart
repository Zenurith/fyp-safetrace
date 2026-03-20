/// One-time migration script: converts legacy integer `role` values in
/// `community_members` to string names matching the new MemberRole enum.
///
/// Legacy mapping:
///   0  → 'member'
///   1  → 'owner'   (if userId == community.creatorId, else 'headModerator')
///
/// Run once via `dart run tools/migrate_member_roles.dart` with your
/// Firebase service account credentials configured, or trigger as a
/// Cloud Function from the Firebase console.
///
/// The app's fromMap() already handles legacy ints via _parseRole(), so
/// this migration is purely for data hygiene.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

Future<void> main() async {
  await Firebase.initializeApp();
  await migrateMemberRoles();
}

Future<void> migrateMemberRoles() async {
  final firestore = FirebaseFirestore.instance;
  final membersRef = firestore.collection('community_members');

  // Fetch all member docs
  final snapshot = await membersRef.get();
  print('Found ${snapshot.docs.length} member documents.');

  // Cache community creatorIds to avoid redundant reads
  final creatorCache = <String, String>{};

  Future<String?> getCreatorId(String communityId) async {
    if (creatorCache.containsKey(communityId)) {
      return creatorCache[communityId];
    }
    final doc =
        await firestore.collection('communities').doc(communityId).get();
    final creatorId = doc.data()?['creatorId'] as String?;
    if (creatorId != null) creatorCache[communityId] = creatorId;
    return creatorId;
  }

  final batch = firestore.batch();
  int migrated = 0;
  int skipped = 0;

  for (final doc in snapshot.docs) {
    final data = doc.data();
    final role = data['role'];

    // Already a string — skip
    if (role is String) {
      skipped++;
      continue;
    }

    final roleInt = role as int? ?? 0;
    final communityId = data['communityId'] as String? ?? '';
    final userId = data['userId'] as String? ?? '';

    String roleName;
    if (roleInt == 0) {
      roleName = 'member';
    } else {
      // Legacy admin (1) — owner if they created the community, else headModerator
      final creatorId = await getCreatorId(communityId);
      roleName = (userId == creatorId) ? 'owner' : 'headModerator';
    }

    batch.update(doc.reference, {'role': roleName});
    migrated++;
  }

  await batch.commit();
  print('Migration complete: $migrated updated, $skipped already migrated.');
}
