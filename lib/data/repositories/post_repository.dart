import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import '../models/community_member_model.dart';

class PostRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _postsCollection =>
      _firestore.collection('posts');

  CollectionReference<Map<String, dynamic>> get _membersCollection =>
      _firestore.collection('community_members');

  // ==================== Post CRUD ====================

  Future<String> createPost(PostModel post) async {
    final docRef = await _postsCollection.add(post.toMap());
    return docRef.id;
  }

  Future<PostModel?> getById(String id) async {
    final doc = await _postsCollection.doc(id).get();
    if (doc.exists && doc.data() != null) {
      return PostModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  Future<void> update(PostModel post) async {
    await _postsCollection.doc(post.id).update(post.toMap());
  }

  Future<void> delete(String id) async {
    await _postsCollection.doc(id).delete();
  }

  // ==================== Moderation ====================

  Future<void> approvePost(String id) async {
    await _postsCollection.doc(id).update({'status': PostStatus.approved.index});
  }

  Future<void> rejectPost(String id) async {
    await _postsCollection.doc(id).update({'status': PostStatus.rejected.index});
  }

  // ==================== Post Queries ====================

  /// Stream of posts from a specific community.
  ///
  /// [staffView] = true → all statuses visible (for staff moderation).
  /// [staffView] = false → only approved posts (for regular members).
  Stream<List<PostModel>> watchCommunityPosts(String communityId, {bool staffView = false}) {
    Query<Map<String, dynamic>> query = _postsCollection
        .where('communityId', isEqualTo: communityId);

    if (!staffView) {
      query = query.where('status', isEqualTo: PostStatus.approved.index);
    }

    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PostModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Stream of pending posts for a community (for staff review queue).
  Stream<List<PostModel>> watchPendingPosts(String communityId) {
    return _postsCollection
        .where('communityId', isEqualTo: communityId)
        .where('status', isEqualTo: PostStatus.pending.index)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PostModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Get all public posts from all communities
  Future<List<PostModel>> getPublicPosts({int? limit}) async {
    Query<Map<String, dynamic>> query = _postsCollection
        .where('visibility', isEqualTo: PostVisibility.public.index)
        .where('status', isEqualTo: PostStatus.approved.index)
        .orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => PostModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Stream of public approved posts
  Stream<List<PostModel>> watchPublicPosts() {
    return _postsCollection
        .where('visibility', isEqualTo: PostVisibility.public.index)
        .where('status', isEqualTo: PostStatus.approved.index)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PostModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Get all posts from a specific community
  Future<List<PostModel>> getCommunityPosts(String communityId) async {
    final snapshot = await _postsCollection
        .where('communityId', isEqualTo: communityId)
        .where('status', isEqualTo: PostStatus.approved.index)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => PostModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Get posts viewable by a user (approved only):
  /// - All public approved posts
  /// - Private approved posts from communities where user is an approved member
  Future<List<PostModel>> getViewablePosts(String userId) async {
    final membershipSnapshot = await _membersCollection
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: MemberStatus.approved.index)
        .get();

    final userCommunityIds = membershipSnapshot.docs
        .map((doc) => doc.data()['communityId'] as String)
        .toList();

    final publicPostsSnapshot = await _postsCollection
        .where('visibility', isEqualTo: PostVisibility.public.index)
        .where('status', isEqualTo: PostStatus.approved.index)
        .orderBy('createdAt', descending: true)
        .get();

    final posts = publicPostsSnapshot.docs
        .map((doc) => PostModel.fromMap(doc.data(), doc.id))
        .toList();

    if (userCommunityIds.isNotEmpty) {
      final privatePosts = await _getPrivatePostsFromCommunities(userCommunityIds);
      posts.addAll(privatePosts);
    }

    posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return posts;
  }

  Future<List<PostModel>> _getPrivatePostsFromCommunities(
      List<String> communityIds) async {
    final posts = <PostModel>[];

    for (var i = 0; i < communityIds.length; i += 10) {
      final batch = communityIds.skip(i).take(10).toList();
      final snapshot = await _postsCollection
          .where('communityId', whereIn: batch)
          .where('visibility', isEqualTo: PostVisibility.private.index)
          .where('status', isEqualTo: PostStatus.approved.index)
          .get();

      posts.addAll(
          snapshot.docs.map((doc) => PostModel.fromMap(doc.data(), doc.id)));
    }

    return posts;
  }

  /// Get posts by a specific author
  Future<List<PostModel>> getPostsByAuthor(String authorId) async {
    final snapshot = await _postsCollection
        .where('authorId', isEqualTo: authorId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => PostModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Stream<List<PostModel>> watchPostsByAuthor(String authorId) {
    return _postsCollection
        .where('authorId', isEqualTo: authorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PostModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // ==================== Media ====================

  Future<void> updateMediaUrls(String postId, List<String> mediaUrls) async {
    await _postsCollection.doc(postId).update({
      'mediaUrls': mediaUrls,
    });
  }

  // ==================== Feed Helpers ====================

  Future<List<PostModel>> getViewablePostsPaginated(
    String userId, {
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    final membershipSnapshot = await _membersCollection
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: MemberStatus.approved.index)
        .get();

    final userCommunityIds = membershipSnapshot.docs
        .map((doc) => doc.data()['communityId'] as String)
        .toSet();

    Query<Map<String, dynamic>> query = _postsCollection
        .orderBy('createdAt', descending: true);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    query = query.limit(limit * 2);

    final snapshot = await query.get();

    final posts = snapshot.docs
        .map((doc) => PostModel.fromMap(doc.data(), doc.id))
        .where((post) =>
            post.isApproved &&
            (post.isPublic || userCommunityIds.contains(post.communityId)))
        .take(limit)
        .toList();

    return posts;
  }
}
