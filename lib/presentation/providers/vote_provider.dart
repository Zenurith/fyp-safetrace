import 'package:flutter/foundation.dart';
import '../../data/models/vote_model.dart';
import '../../data/repositories/vote_repository.dart';

class VoteProvider extends ChangeNotifier {
  final VoteRepository _repository = VoteRepository();

  // Cache of user votes by targetId (incidents and posts share the same key space
  // since Firestore IDs are globally unique — no collision risk)
  final Map<String, VoteModel> _userVotes = {};
  final Map<String, VoteModel> _userPostVotes = {};
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Gets the cached vote for an incident, or null if not voted.
  VoteModel? getVoteForIncident(String incidentId) => _userVotes[incidentId];

  /// Gets the cached vote for a post, or null if not voted.
  VoteModel? getVoteForPost(String postId) => _userPostVotes[postId];

  /// Loads all votes by the current user and caches them by type.
  Future<void> loadUserVotes(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final votes = await _repository.getVotesByUser(userId);
      _userVotes.clear();
      _userPostVotes.clear();
      for (final vote in votes) {
        if (vote.targetType == VoteTargetType.post) {
          _userPostVotes[vote.targetId] = vote;
        } else {
          // VoteTargetType.incident (including legacy docs without targetType)
          _userVotes[vote.targetId] = vote;
        }
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Incident Votes
  // ══════════════════════════════════════════════════════════════════════════

  /// Casts or changes a vote on an incident.
  /// Returns true if the vote was successful.
  Future<bool> vote({
    required String incidentId,
    required String voterId,
    required String reporterId,
    required VoteType type,
  }) async {
    if (voterId == reporterId) {
      _error = 'Cannot vote on your own report';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final existingVote = _userVotes[incidentId];

      VoteModel? result;
      if (existingVote == null) {
        result = await _repository.castVote(
          incidentId: incidentId,
          voterId: voterId,
          reporterId: reporterId,
          type: type,
        );
      } else if (existingVote.type != type) {
        result = await _repository.changeVote(
          incidentId: incidentId,
          voterId: voterId,
          reporterId: reporterId,
          newType: type,
        );
      } else {
        // Same vote type — toggle off
        final removed = await _repository.removeVote(
          incidentId: incidentId,
          voterId: voterId,
          reporterId: reporterId,
        );
        if (removed) {
          _userVotes.remove(incidentId);
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }

      if (result != null) {
        _userVotes[incidentId] = result;
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Removes a vote from an incident.
  Future<bool> removeVote({
    required String incidentId,
    required String voterId,
    required String reporterId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final removed = await _repository.removeVote(
        incidentId: incidentId,
        voterId: voterId,
        reporterId: reporterId,
      );

      if (removed) {
        _userVotes.remove(incidentId);
      }

      _isLoading = false;
      notifyListeners();
      return removed;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Post Votes
  // ══════════════════════════════════════════════════════════════════════════

  /// Casts, changes, or toggles a vote on a post.
  /// Returns true if the vote was successful.
  Future<bool> voteOnPost({
    required String postId,
    required String voterId,
    required String authorId,
    required VoteType type,
  }) async {
    if (voterId == authorId) {
      _error = 'Cannot vote on your own post';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final existingVote = _userPostVotes[postId];

      VoteModel? result;
      if (existingVote == null) {
        result = await _repository.castPostVote(
          postId: postId,
          voterId: voterId,
          authorId: authorId,
          type: type,
        );
      } else if (existingVote.type != type) {
        result = await _repository.changePostVote(
          postId: postId,
          voterId: voterId,
          newType: type,
        );
      } else {
        // Same vote type — toggle off
        final removed = await _repository.removePostVote(
          postId: postId,
          voterId: voterId,
        );
        if (removed) {
          _userPostVotes.remove(postId);
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }

      if (result != null) {
        _userPostVotes[postId] = result;
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Clears the vote cache (e.g., on logout).
  void clearCache() {
    _userVotes.clear();
    _userPostVotes.clear();
    _error = null;
    notifyListeners();
  }
}
