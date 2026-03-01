import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/comment_model.dart';
import '../../data/repositories/comment_repository.dart';

class CommentProvider extends ChangeNotifier {
  final CommentRepository _repository = CommentRepository();

  final Map<String, List<CommentModel>> _commentsByIncident = {};
  final Map<String, StreamSubscription> _subscriptions = {};
  bool _isLoading = false;
  String? _error;

  List<CommentModel> getComments(String incidentId) {
    return _commentsByIncident[incidentId] ?? [];
  }

  bool get isLoading => _isLoading;
  String? get error => _error;

  void startListening(String incidentId) {
    // Don't create duplicate subscriptions
    if (_subscriptions.containsKey(incidentId)) return;

    _subscriptions[incidentId] = _repository.watchByIncident(incidentId).listen(
      (comments) {
        _commentsByIncident[incidentId] = comments;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  void stopListening(String incidentId) {
    _subscriptions[incidentId]?.cancel();
    _subscriptions.remove(incidentId);
  }

  @override
  void dispose() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }

  Future<bool> addComment({
    required String incidentId,
    required String authorId,
    required String authorName,
    String? authorPhotoUrl,
    required String content,
  }) async {
    if (content.trim().isEmpty) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final comment = CommentModel(
        id: '',
        incidentId: incidentId,
        authorId: authorId,
        authorName: authorName,
        authorPhotoUrl: authorPhotoUrl,
        content: content.trim(),
        createdAt: DateTime.now(),
      );

      await _repository.add(comment);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteComment(String commentId) async {
    try {
      await _repository.delete(commentId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateComment(String commentId, String content) async {
    if (content.trim().isEmpty) return false;

    try {
      await _repository.update(commentId, content.trim());
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
