import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/community_model.dart';
import '../models/community_member_model.dart';

class CommunityRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _communitiesCollection =>
      _firestore.collection('communities');

  CollectionReference<Map<String, dynamic>> get _membersCollection =>
      _firestore.collection('community_members');

  // ==================== Community CRUD ====================

  /// Create a new community and automatically add the creator as owner.
  Future<String> createCommunity(CommunityModel community) async {
    final batch = _firestore.batch();

    final communityRef = _communitiesCollection.doc();
    batch.set(communityRef, community.toMap());

    final memberRef = _membersCollection.doc();
    final creatorMember = CommunityMemberModel(
      id: memberRef.id,
      communityId: communityRef.id,
      userId: community.creatorId,
      status: MemberStatus.approved,
      role: MemberRole.owner,
      requestedAt: DateTime.now(),
      approvedAt: DateTime.now(),
      approvedBy: community.creatorId,
    );
    batch.set(memberRef, creatorMember.toMap());

    await batch.commit();
    return communityRef.id;
  }

  Future<CommunityModel?> getById(String id) async {
    final doc = await _communitiesCollection.doc(id).get();
    if (doc.exists && doc.data() != null) {
      return CommunityModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  Future<void> update(CommunityModel community) async {
    await _communitiesCollection.doc(community.id).update(community.toMap());
  }

  Future<void> delete(String id) async {
    final membersSnapshot =
        await _membersCollection.where('communityId', isEqualTo: id).get();
    final batch = _firestore.batch();
    for (final doc in membersSnapshot.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_communitiesCollection.doc(id));
    await batch.commit();
  }

  Stream<List<CommunityModel>> watchAll() {
    return _communitiesCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CommunityModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Get communities within range of a given location.
  Future<List<CommunityModel>> getNearbyCommunities(
    double latitude,
    double longitude, {
    double maxDistance = 50,
  }) async {
    final snapshot = await _communitiesCollection.get();
    final communities = snapshot.docs
        .map((doc) => CommunityModel.fromMap(doc.data(), doc.id))
        .toList();

    return communities.where((community) {
      final distance = community.calculateDistance(latitude, longitude);
      return community.isLocationWithinRadius(latitude, longitude) ||
          distance <= maxDistance;
    }).toList();
  }

  /// Returns all membership records for a user in a single query.
  Future<List<CommunityMemberModel>> getUserMemberships(String userId) async {
    final snapshot = await _membersCollection
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.docs
        .map((doc) => CommunityMemberModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Batch-fetch communities by IDs (handles Firestore's 10-item whereIn limit).
  Future<List<CommunityModel>> getCommunitiesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final communities = <CommunityModel>[];
    for (var i = 0; i < ids.length; i += 10) {
      final batch = ids.skip(i).take(10).toList();
      final snapshot = await _communitiesCollection
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      communities.addAll(
          snapshot.docs.map((doc) => CommunityModel.fromMap(doc.data(), doc.id)));
    }
    return communities;
  }

  Future<List<CommunityModel>> getUserCommunities(String userId) async {
    final memberships = await getUserMemberships(userId);
    final approvedIds = memberships
        .where((m) => m.isApproved)
        .map((m) => m.communityId)
        .toList();
    return getCommunitiesByIds(approvedIds);
  }

  // ==================== Membership Management ====================

  /// Request to join a community.
  Future<String> requestToJoin(String communityId, String userId) async {
    final existingMembership = await _membersCollection
        .where('communityId', isEqualTo: communityId)
        .where('userId', isEqualTo: userId)
        .get();

    final communityDoc = await _communitiesCollection.doc(communityId).get();
    final requiresApproval = communityDoc.data()?['requiresApproval'] ?? false;

    if (existingMembership.docs.isNotEmpty) {
      final member = CommunityMemberModel.fromMap(
        existingMembership.docs.first.data(),
        existingMembership.docs.first.id,
      );
      if (member.isApproved) {
        throw Exception('Already a member of this community');
      }
      if (member.isPending) {
        throw Exception('Join request already pending');
      }
      if (member.isBanned) {
        final until = member.bannedUntil;
        if (until == null) {
          throw Exception('You are permanently banned from this community.');
        }
        if (until.isAfter(DateTime.now())) {
          final d = until;
          throw Exception(
              'You are banned until ${d.day}/${d.month}/${d.year}.');
        }
        // Temp ban expired — fall through and allow re-apply
      }

      if (requiresApproval) {
        await _membersCollection.doc(existingMembership.docs.first.id).update({
          'status': MemberStatus.pending.index,
          'requestedAt': Timestamp.now(),
        });
      } else {
        await _membersCollection.doc(existingMembership.docs.first.id).update({
          'status': MemberStatus.approved.index,
          'requestedAt': Timestamp.now(),
          'approvedAt': Timestamp.now(),
          'approvedBy': 'auto',
        });
        await _communitiesCollection.doc(communityId).update({
          'memberCount': FieldValue.increment(1),
        });
      }
      return existingMembership.docs.first.id;
    }

    final member = CommunityMemberModel(
      id: '',
      communityId: communityId,
      userId: userId,
      status: requiresApproval ? MemberStatus.pending : MemberStatus.approved,
      role: MemberRole.member,
      requestedAt: DateTime.now(),
      approvedAt: requiresApproval ? null : DateTime.now(),
      approvedBy: requiresApproval ? null : 'auto',
    );

    final docRef = await _membersCollection.add(member.toMap());

    if (!requiresApproval) {
      await _communitiesCollection.doc(communityId).update({
        'memberCount': FieldValue.increment(1),
      });
    }

    return docRef.id;
  }

  /// Approve a membership request (staff only).
  Future<void> approveRequest(
      String memberId, String communityId, String approvedBy) async {
    await _membersCollection.doc(memberId).update({
      'status': MemberStatus.approved.index,
      'approvedAt': Timestamp.now(),
      'approvedBy': approvedBy,
    });
    await _communitiesCollection.doc(communityId).update({
      'memberCount': FieldValue.increment(1),
    });
  }

  /// Reject a membership request (staff only).
  Future<void> rejectRequest(String memberId) async {
    await _membersCollection.doc(memberId).update({
      'status': MemberStatus.rejected.index,
    });
  }

  /// Get all pending requests for a community (for staff view).
  Future<List<CommunityMemberModel>> getPendingRequests(
      String communityId) async {
    final snapshot = await _membersCollection
        .where('communityId', isEqualTo: communityId)
        .where('status', isEqualTo: MemberStatus.pending.index)
        .orderBy('requestedAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => CommunityMemberModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Get all approved members of a community.
  Future<List<CommunityMemberModel>> getCommunityMembers(
      String communityId) async {
    final snapshot = await _membersCollection
        .where('communityId', isEqualTo: communityId)
        .where('status', isEqualTo: MemberStatus.approved.index)
        .get();

    return snapshot.docs
        .map((doc) => CommunityMemberModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Check if a user is an approved member of a community.
  Future<bool> isMember(String communityId, String userId) async {
    final snapshot = await _membersCollection
        .where('communityId', isEqualTo: communityId)
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: MemberStatus.approved.index)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  /// Check if a user holds a staff role (owner, headModerator, or moderator).
  Future<bool> isStaff(String communityId, String userId) async {
    final membership = await getUserMembership(communityId, userId);
    return membership != null && membership.isApproved && membership.isStaff;
  }

  /// Check if a user is the owner of a community.
  Future<bool> isOwnerOf(String communityId, String userId) async {
    final membership = await getUserMembership(communityId, userId);
    return membership != null && membership.isApproved && membership.isOwner;
  }

  /// Get user's membership for a specific community.
  Future<CommunityMemberModel?> getUserMembership(
      String communityId, String userId) async {
    final snapshot = await _membersCollection
        .where('communityId', isEqualTo: communityId)
        .where('userId', isEqualTo: userId)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return CommunityMemberModel.fromMap(
        snapshot.docs.first.data(),
        snapshot.docs.first.id,
      );
    }
    return null;
  }

  /// Leave a community. Throws if the user is the owner.
  Future<void> leaveCommunity(String communityId, String userId) async {
    final membership = await getUserMembership(communityId, userId);
    if (membership == null) return;

    if (membership.isOwner) {
      throw Exception('Transfer ownership before leaving.');
    }

    await _membersCollection.doc(membership.id).delete();

    if (membership.isApproved) {
      await _communitiesCollection.doc(communityId).update({
        'memberCount': FieldValue.increment(-1),
      });
    }
  }

  /// Promote a member to moderator.
  Future<void> promoteToModerator(String memberId) async {
    await _membersCollection.doc(memberId).update({
      'role': MemberRole.moderator.name,
    });
  }

  /// Promote a moderator to head moderator.
  Future<void> promoteToHeadModerator(String memberId) async {
    await _membersCollection.doc(memberId).update({
      'role': MemberRole.headModerator.name,
    });
  }

  /// Demote a staff member to regular member. Throws if target is owner.
  Future<void> demoteToMember(String memberId, String communityId) async {
    final doc = await _membersCollection.doc(memberId).get();
    if (!doc.exists) throw Exception('Member not found.');
    final member = CommunityMemberModel.fromMap(doc.data()!, doc.id);
    if (member.isOwner) throw Exception('Cannot demote the community owner.');

    await _membersCollection.doc(memberId).update({
      'role': MemberRole.member.name,
    });
  }

  /// Ban a member from the community.
  /// [bannedUntil] = null → permanent ban; non-null → temporary ban.
  /// Throws if target is owner.
  Future<void> banMember(
      String memberId, String communityId, {DateTime? bannedUntil}) async {
    final doc = await _membersCollection.doc(memberId).get();
    if (!doc.exists) throw Exception('Member not found.');
    final member = CommunityMemberModel.fromMap(doc.data()!, doc.id);
    if (member.isOwner) throw Exception('Cannot ban the community owner.');

    final wasApproved = member.isApproved;
    await _membersCollection.doc(memberId).update({
      'status': MemberStatus.banned.index,
      'bannedUntil':
          bannedUntil != null ? Timestamp.fromDate(bannedUntil) : null,
    });

    if (wasApproved) {
      await _communitiesCollection.doc(communityId).update({
        'memberCount': FieldValue.increment(-1),
      });
    }
  }

  /// Remove a member by their membership document ID. Throws if target is owner.
  Future<void> removeMemberById(String memberId, String communityId) async {
    final doc = await _membersCollection.doc(memberId).get();
    if (!doc.exists) return;
    final member = CommunityMemberModel.fromMap(doc.data()!, doc.id);
    if (member.isOwner) throw Exception('Cannot remove the community owner.');

    await _membersCollection.doc(memberId).delete();

    if (member.isApproved) {
      await _communitiesCollection.doc(communityId).update({
        'memberCount': FieldValue.increment(-1),
      });
    }
  }

  /// Transfer ownership. Old owner becomes headModerator; new member becomes owner.
  Future<void> transferOwnership(
      String communityId, String currentOwnerId, String newOwnerId) async {
    final ownerMembership =
        await getUserMembership(communityId, currentOwnerId);
    final newOwnerMembership =
        await getUserMembership(communityId, newOwnerId);

    if (ownerMembership == null) {
      throw Exception('Current owner membership not found.');
    }
    if (newOwnerMembership == null) {
      throw Exception('Target member not found in community.');
    }
    if (newOwnerMembership.isOwner) {
      throw Exception('Target is already the owner.');
    }

    final batch = _firestore.batch();
    batch.update(_membersCollection.doc(ownerMembership.id), {
      'role': MemberRole.headModerator.name,
    });
    batch.update(_membersCollection.doc(newOwnerMembership.id), {
      'role': MemberRole.owner.name,
    });
    await batch.commit();
  }
}
