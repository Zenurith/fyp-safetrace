import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/post_model.dart';
import '../../data/repositories/post_repository.dart';

class PostProvider extends ChangeNotifier {
  final PostRepository _repository = PostRepository();

  List<PostModel> _communityPosts = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _postsSubscription;

  List<PostModel> get communityPosts => _communityPosts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void startListening(String communityId) {
    _postsSubscription?.cancel();
    _postsSubscription = _repository.watchCommunityPosts(communityId).listen(
      (posts) {
        _communityPosts = posts;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  void stopListening() {
    _postsSubscription?.cancel();
    _postsSubscription = null;
  }

  Future<String?> createPost({
    required String authorId,
    required String communityId,
    required String title,
    required String content,
    PostVisibility visibility = PostVisibility.public,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final post = PostModel(
        id: '',
        authorId: authorId,
        communityId: communityId,
        visibility: visibility,
        title: title,
        content: content,
        createdAt: DateTime.now(),
      );
      final id = await _repository.createPost(post);
      _isLoading = false;
      notifyListeners();
      return id;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> deletePost(String postId) async {
    try {
      await _repository.delete(postId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _postsSubscription?.cancel();
    super.dispose();
  }
}
