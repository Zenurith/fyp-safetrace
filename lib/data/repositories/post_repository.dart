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

  // ==================== Post Queries ====================

  /// Get all public posts from all communities
  Future<List<PostModel>> getPublicPosts({int? limit}) async {
    Query<Map<String, dynamic>> query = _postsCollection
        .where('visibility', isEqualTo: PostVisibility.public.index)
        .orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => PostModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Stream of public posts
  Stream<List<PostModel>> watchPublicPosts() {
    return _postsCollection
        .where('visibility', isEqualTo: PostVisibility.public.index)
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
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => PostModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Stream of posts from a specific community
  Stream<List<PostModel>> watchCommunityPosts(String communityId) {
    return _postsCollection
        .where('communityId', isEqualTo: communityId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PostModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Get posts viewable by a user:
  /// - All public posts
  /// - Private posts from communities where user is an approved member
  Future<List<PostModel>> getViewablePosts(String userId) async {
    // Get user's approved community memberships
    final membershipSnapshot = await _membersCollection
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: MemberStatus.approved.index)
        .get();

    final userCommunityIds = membershipSnapshot.docs
        .map((doc) => doc.data()['communityId'] as String)
        .toList();

    // Get all public posts
    final publicPostsSnapshot = await _postsCollection
        .where('visibility', isEqualTo: PostVisibility.public.index)
        .orderBy('createdAt', descending: true)
        .get();

    final posts = publicPostsSnapshot.docs
        .map((doc) => PostModel.fromMap(doc.data(), doc.id))
        .toList();

    // Get private posts from user's communities (batch to handle whereIn limit)
    if (userCommunityIds.isNotEmpty) {
      final privatePosts = await _getPrivatePostsFromCommunities(userCommunityIds);
      posts.addAll(privatePosts);
    }

    // Sort combined posts by createdAt descending
    posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return posts;
  }

  /// Helper method to batch fetch private posts from multiple communities
  /// Handles Firestore's 10-item whereIn limit
  Future<List<PostModel>> _getPrivatePostsFromCommunities(
      List<String> communityIds) async {
    final posts = <PostModel>[];

    // Process in batches of 10 due to Firestore whereIn limit
    for (var i = 0; i < communityIds.length; i += 10) {
      final batch = communityIds.skip(i).take(10).toList();
      final snapshot = await _postsCollection
          .where('communityId', whereIn: batch)
          .where('visibility', isEqualTo: PostVisibility.private.index)
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

  /// Stream of posts by a specific author
  Stream<List<PostModel>> watchPostsByAuthor(String authorId) {
    return _postsCollection
        .where('authorId', isEqualTo: authorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PostModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // ==================== Voting ====================

  Future<void> upvote(String postId) async {
    await _postsCollection.doc(postId).update({
      'upvotes': FieldValue.increment(1),
    });
  }

  Future<void> downvote(String postId) async {
    await _postsCollection.doc(postId).update({
      'downvotes': FieldValue.increment(1),
    });
  }

  Future<void> removeUpvote(String postId) async {
    await _postsCollection.doc(postId).update({
      'upvotes': FieldValue.increment(-1),
    });
  }

  Future<void> removeDownvote(String postId) async {
    await _postsCollection.doc(postId).update({
      'downvotes': FieldValue.increment(-1),
    });
  }

  // ==================== Media ====================

  Future<void> updateMediaUrls(String postId, List<String> mediaUrls) async {
    await _postsCollection.doc(postId).update({
      'mediaUrls': mediaUrls,
    });
  }

  // ==================== Feed Helpers ====================

  /// Get paginated viewable posts for infinite scroll
  Future<List<PostModel>> getViewablePostsPaginated(
    String userId, {
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    // Get user's approved community memberships
    final membershipSnapshot = await _membersCollection
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: MemberStatus.approved.index)
        .get();

    final userCommunityIds = membershipSnapshot.docs
        .map((doc) => doc.data()['communityId'] as String)
        .toSet();

    // Build query for public posts
    Query<Map<String, dynamic>> query = _postsCollection
        .orderBy('createdAt', descending: true);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    query = query.limit(limit * 2); // Fetch extra to filter private posts

    final snapshot = await query.get();

    // Filter posts: public OR (private AND user is member of community)
    final posts = snapshot.docs
        .map((doc) => PostModel.fromMap(doc.data(), doc.id))
        .where((post) =>
            post.isPublic || userCommunityIds.contains(post.communityId))
        .take(limit)
        .toList();

    return posts;
  }
}
