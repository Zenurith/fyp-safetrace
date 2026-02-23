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

  /// Create a new community and automatically add the creator as admin
  Future<String> createCommunity(CommunityModel community) async {
    final batch = _firestore.batch();

    // Create the community document
    final communityRef = _communitiesCollection.doc();
    batch.set(communityRef, community.toMap());

    // Add creator as admin member
    final memberRef = _membersCollection.doc();
    final creatorMember = CommunityMemberModel(
      id: memberRef.id,
      communityId: communityRef.id,
      userId: community.creatorId,
      status: MemberStatus.approved,
      role: MemberRole.admin,
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
    // Delete all members first
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

  /// Get communities within range of a given location
  Future<List<CommunityModel>> getNearbyCommunities(
    double latitude,
    double longitude, {
    double maxDistance = 50, // Default 50km search radius
  }) async {
    // Firestore doesn't support geo queries natively, so we fetch all and filter
    // For production, consider using GeoFlutterFire or geohashing
    final snapshot = await _communitiesCollection.get();
    final communities = snapshot.docs
        .map((doc) => CommunityModel.fromMap(doc.data(), doc.id))
        .toList();

    // Filter communities where the given location is within their radius
    // OR the community center is within maxDistance of the given location
    return communities.where((community) {
      final distance = community.calculateDistance(latitude, longitude);
      return community.isLocationWithinRadius(latitude, longitude) ||
          distance <= maxDistance;
    }).toList();
  }

  /// Get all communities where the user is an approved member
  Future<List<CommunityModel>> getUserCommunities(String userId) async {
    // Get all approved memberships for this user
    final membershipSnapshot = await _membersCollection
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: MemberStatus.approved.index)
        .get();

    if (membershipSnapshot.docs.isEmpty) {
      return [];
    }

    final communityIds = membershipSnapshot.docs
        .map((doc) => doc.data()['communityId'] as String)
        .toList();

    // Batch fetch communities (handle Firestore's 10-item whereIn limit)
    final communities = <CommunityModel>[];
    for (var i = 0; i < communityIds.length; i += 10) {
      final batch = communityIds.skip(i).take(10).toList();
      final snapshot = await _communitiesCollection
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      communities.addAll(snapshot.docs
          .map((doc) => CommunityModel.fromMap(doc.data(), doc.id)));
    }

    return communities;
  }

  // ==================== Membership Management ====================

  /// Request to join a community (auto-approved for testing)
  Future<String> requestToJoin(String communityId, String userId) async {
    // Check if already a member or has pending request
    final existingMembership = await _membersCollection
        .where('communityId', isEqualTo: communityId)
        .where('userId', isEqualTo: userId)
        .get();

    if (existingMembership.docs.isNotEmpty) {
      final member = CommunityMemberModel.fromMap(
        existingMembership.docs.first.data(),
        existingMembership.docs.first.id,
      );
      if (member.isApproved) {
        throw Exception('Already a member of this community');
      }
      // Auto-approve: update existing record to approved
      await _membersCollection.doc(existingMembership.docs.first.id).update({
        'status': MemberStatus.approved.index,
        'requestedAt': Timestamp.now(),
        'approvedAt': Timestamp.now(),
        'approvedBy': 'auto',
      });
      // Increment member count
      await _communitiesCollection.doc(communityId).update({
        'memberCount': FieldValue.increment(1),
      });
      return existingMembership.docs.first.id;
    }

    // Auto-approve: create as approved member directly
    final member = CommunityMemberModel(
      id: '',
      communityId: communityId,
      userId: userId,
      status: MemberStatus.approved,
      role: MemberRole.member,
      requestedAt: DateTime.now(),
      approvedAt: DateTime.now(),
      approvedBy: 'auto',
    );

    final docRef = await _membersCollection.add(member.toMap());

    // Increment member count
    await _communitiesCollection.doc(communityId).update({
      'memberCount': FieldValue.increment(1),
    });

    return docRef.id;
  }

  /// Approve a membership request (admin only)
  Future<void> approveRequest(String memberId, String approvedBy) async {
    await _membersCollection.doc(memberId).update({
      'status': MemberStatus.approved.index,
      'approvedAt': Timestamp.now(),
      'approvedBy': approvedBy,
    });

    // Increment community member count
    final memberDoc = await _membersCollection.doc(memberId).get();
    if (memberDoc.exists) {
      final communityId = memberDoc.data()!['communityId'] as String;
      await _communitiesCollection.doc(communityId).update({
        'memberCount': FieldValue.increment(1),
      });
    }
  }

  /// Reject a membership request (admin only)
  Future<void> rejectRequest(String memberId) async {
    await _membersCollection.doc(memberId).update({
      'status': MemberStatus.rejected.index,
    });
  }

  /// Get all pending requests for a community (for admin view)
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

  /// Get all members of a community
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

  /// Check if a user is an approved member of a community
  Future<bool> isMember(String communityId, String userId) async {
    final snapshot = await _membersCollection
        .where('communityId', isEqualTo: communityId)
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: MemberStatus.approved.index)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  /// Check if a user is an admin of a community
  Future<bool> isAdmin(String communityId, String userId) async {
    final snapshot = await _membersCollection
        .where('communityId', isEqualTo: communityId)
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: MemberStatus.approved.index)
        .where('role', isEqualTo: MemberRole.admin.index)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  /// Get user's membership for a specific community
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

  /// Leave a community
  Future<void> leaveCommunity(String communityId, String userId) async {
    final membership = await getUserMembership(communityId, userId);
    if (membership == null) return;

    // Prevent admin from leaving if they're the only admin
    if (membership.isAdmin) {
      final admins = await _membersCollection
          .where('communityId', isEqualTo: communityId)
          .where('role', isEqualTo: MemberRole.admin.index)
          .where('status', isEqualTo: MemberStatus.approved.index)
          .get();

      if (admins.docs.length <= 1) {
        throw Exception(
            'Cannot leave community. You are the only admin. Transfer admin role first.');
      }
    }

    await _membersCollection.doc(membership.id).delete();

    // Decrement member count if was approved
    if (membership.isApproved) {
      await _communitiesCollection.doc(communityId).update({
        'memberCount': FieldValue.increment(-1),
      });
    }
  }

  /// Promote a member to admin
  Future<void> promoteToAdmin(String memberId) async {
    await _membersCollection.doc(memberId).update({
      'role': MemberRole.admin.index,
    });
  }

  /// Demote an admin to regular member
  Future<void> demoteToMember(String memberId, String communityId) async {
    // Check if there are other admins
    final admins = await _membersCollection
        .where('communityId', isEqualTo: communityId)
        .where('role', isEqualTo: MemberRole.admin.index)
        .where('status', isEqualTo: MemberStatus.approved.index)
        .get();

    if (admins.docs.length <= 1) {
      throw Exception('Cannot demote. Community must have at least one admin.');
    }

    await _membersCollection.doc(memberId).update({
      'role': MemberRole.member.index,
    });
  }
}
