import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/post_model.dart';
import '../../data/repositories/post_repository.dart';

class PostProvider extends ChangeNotifier {
  final PostRepository _repository = PostRepository();

  List<PostModel> _posts = [];
  bool _isLoading = false;
  String? _error;
  String? _activeCommunityId;
  StreamSubscription? _postsSubscription;

  List<PostModel> get posts => _posts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Subscribe to real-time posts for a community. No-op if already watching this community.
  void watchCommunityPosts(String communityId) {
    if (_activeCommunityId == communityId) return;
    _activeCommunityId = communityId;
    _postsSubscription?.cancel();
    _posts = [];
    _isLoading = true;
    notifyListeners();

    _postsSubscription = _repository.watchCommunityPosts(communityId).listen(
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
    _posts = [];
    _isLoading = false;
    _error = null;
  }

  @override
  void dispose() {
    _postsSubscription?.cancel();
    super.dispose();
  }
}
