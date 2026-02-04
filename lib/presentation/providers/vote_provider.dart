import 'package:flutter/foundation.dart';
import '../../data/models/vote_model.dart';
import '../../data/repositories/vote_repository.dart';

class VoteProvider extends ChangeNotifier {
  final VoteRepository _repository = VoteRepository();

  // Cache of user votes by incidentId for quick UI lookups
  final Map<String, VoteModel> _userVotes = {};
  bool _isLoading = false;
  String? _error;

  Map<String, VoteModel> get userVotes => Map.unmodifiable(_userVotes);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Gets the cached vote for an incident, or null if not voted.
  VoteModel? getVoteForIncident(String incidentId) {
    return _userVotes[incidentId];
  }

  /// Loads all votes by the current user and caches them.
  Future<void> loadUserVotes(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final votes = await _repository.getVotesByUser(userId);
      _userVotes.clear();
      for (final vote in votes) {
        _userVotes[vote.incidentId] = vote;
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Casts or changes a vote on an incident.
  /// Returns true if the vote was successful.
  Future<bool> vote({
    required String incidentId,
    required String voterId,
    required String reporterId,
    required VoteType type,
  }) async {
    // Prevent voting on own reports
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
        // Cast new vote
        result = await _repository.castVote(
          incidentId: incidentId,
          voterId: voterId,
          reporterId: reporterId,
          type: type,
        );
      } else if (existingVote.type != type) {
        // Change existing vote
        result = await _repository.changeVote(
          incidentId: incidentId,
          voterId: voterId,
          reporterId: reporterId,
          newType: type,
        );
      } else {
        // Same vote type, remove the vote (toggle behavior)
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

  /// Clears the vote cache (e.g., on logout).
  void clearCache() {
    _userVotes.clear();
    _error = null;
    notifyListeners();
  }
}
