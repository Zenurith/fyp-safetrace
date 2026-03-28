import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/post_model.dart';
import '../../data/repositories/post_repository.dart';

class PostProvider extends ChangeNotifier {
  final PostRepository _repository = PostRepository();

  List<PostModel> _posts = [];
  List<PostModel> _pendingPosts = [];
  bool _isLoading = false;
  String? _error;
  String? _activeCommunityId;
  StreamSubscription? _postsSubscription;
  StreamSubscription? _pendingSubscription;

  List<PostModel> get posts => _posts;
  List<PostModel> get pendingPosts => _pendingPosts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Subscribe to real-time posts for a community.
  ///
  /// Staff see all posts (pending + approved); members see only approved.
  void watchCommunityPosts(String communityId, {bool isStaff = false}) {
    // Re-subscribe if the community changed OR if the subscription was cancelled
    // (e.g. stopWatching() was called by another tab).
    if (_activeCommunityId == communityId && _postsSubscription != null) return;
    _activeCommunityId = communityId;
    _postsSubscription?.cancel();
    _posts = [];
    _isLoading = true;
    notifyListeners();

    _postsSubscription = _repository
        .watchCommunityPosts(communityId, staffView: isStaff)
        .listen(
      (posts) {
        _posts = posts;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  /// Subscribe to pending posts for the manager review queue.
  void watchPendingPosts(String communityId) {
    _pendingSubscription?.cancel();
    _pendingPosts = [];
    notifyListeners();

    _pendingSubscription = _repository.watchPendingPosts(communityId).listen(
      (posts) {
        _pendingPosts = posts;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  Future<bool> createPost(PostModel post) async {
    try {
      await _repository.createPost(post);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> approvePost(String id) async {
    try {
      await _repository.approvePost(id);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectPost(String id) async {
    try {
      await _repository.rejectPost(id);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deletePost(String id) async {
    try {
      await _repository.delete(id);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void stopWatching() {
    _activeCommunityId = null;
    _postsSubscription?.cancel();
    _pendingSubscription?.cancel();
    _posts = [];
    _pendingPosts = [];
    _isLoading = false;
    _error = null;
  }

  /// Stops only the pending-posts subscription (used when the manager tab closes,
  /// so the main posts subscription in the Posts tab is not affected).
  void stopWatchingPending() {
    _pendingSubscription?.cancel();
    _pendingPosts = [];
  }

  @override
  void dispose() {
    _postsSubscription?.cancel();
    _pendingSubscription?.cancel();
    super.dispose();
  }
}
