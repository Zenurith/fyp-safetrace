import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vote_model.dart';
import '../models/incident_model.dart';
import 'user_repository.dart';

class VoteRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserRepository _userRepository = UserRepository();

  CollectionReference<Map<String, dynamic>> get _votesCollection =>
      _firestore.collection('votes');

  CollectionReference<Map<String, dynamic>> get _incidentsCollection =>
      _firestore.collection('incidents');

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  /// Auto-status thresholds
  static const int _upvotesForUnderReview = 1;  // 1+ upvotes → under review
  static const int _upvotesForVerified = 2;     // 2+ upvotes → verified
  static const int _scoreForVerified = 1;       // AND score ≥ 1
  static const int _downvotesForDismissed = 2;  // 2+ downvotes → dismissed
  static const int _scoreForDismissed = -2;     // AND score ≤ -2

  /// Determines the appropriate status based on vote counts.
  /// Returns null if status should not change.
  IncidentStatus? _calculateAutoStatus({
    required int upvotes,
    required int downvotes,
    required IncidentStatus currentStatus,
  }) {
    final voteScore = upvotes - downvotes;

    // Don't auto-change if already resolved or dismissed by admin
    if (currentStatus == IncidentStatus.resolved) {
      return null;
    }

    // Check for dismissal (high downvotes)
    if (downvotes >= _downvotesForDismissed && voteScore <= _scoreForDismissed) {
      if (currentStatus != IncidentStatus.dismissed) {
        return IncidentStatus.dismissed;
      }
      return null;
    }

    // Check for verified (enough upvotes and good score)
    if (upvotes >= _upvotesForVerified && voteScore >= _scoreForVerified) {
      if (currentStatus != IncidentStatus.verified) {
        return IncidentStatus.verified;
      }
      return null;
    }

    // Check for under review (some upvotes)
    if (upvotes >= _upvotesForUnderReview) {
      if (currentStatus == IncidentStatus.pending) {
        return IncidentStatus.underReview;
      }
      return null;
    }

    return null;
  }

  /// Casts a vote on an incident using a Firestore transaction.
  /// Returns the created vote, or null if the user is trying to vote on their own report.
  Future<VoteModel?> castVote({
    required String incidentId,
    required String voterId,
    required String reporterId,
    required VoteType type,
  }) async {
    // Prevent users from voting on their own reports
    if (voterId == reporterId) {
      return null;
    }

    final voteDocId = '${incidentId}_$voterId';
    final voteRef = _votesCollection.doc(voteDocId);
    final incidentRef = _incidentsCollection.doc(incidentId);
    final reporterRef = _usersCollection.doc(reporterId);
    final voterRef = _usersCollection.doc(voterId);

    final result = await _firestore.runTransaction<VoteModel?>((transaction) async {
      // Read all documents first (required for Firestore transactions)
      final existingVoteDoc = await transaction.get(voteRef);
      final incidentDoc = await transaction.get(incidentRef);
      final reporterDoc = await transaction.get(reporterRef);
      final voterDoc = await transaction.get(voterRef);

      if (existingVoteDoc.exists) {
        // Vote already exists - use changeVote instead
        return null;
      }

      // Verify incident exists
      if (!incidentDoc.exists) {
        throw Exception('Incident not found');
      }

      final vote = VoteModel(
        id: voteDocId,
        incidentId: incidentId,
        voterId: voterId,
        type: type,
        votedAt: DateTime.now(),
      );

      // Create vote document
      transaction.set(voteRef, vote.toMap());

      // Update incident vote counts (use set with merge in case fields don't exist)
      final incidentData = incidentDoc.data() ?? {};
      final currentUpvotes = incidentData['upvotes'] ?? 0;
      final currentDownvotes = incidentData['downvotes'] ?? 0;
      final currentStatus = IncidentStatus.values[incidentData['status'] ?? 0];

      final newUpvotes = type == VoteType.upvote ? currentUpvotes + 1 : currentUpvotes;
      final newDownvotes = type == VoteType.downvote ? currentDownvotes + 1 : currentDownvotes;

      // Calculate if status should auto-change
      final newStatus = _calculateAutoStatus(
        upvotes: newUpvotes,
        downvotes: newDownvotes,
        currentStatus: currentStatus,
      );

      final incidentUpdate = <String, dynamic>{
        'upvotes': newUpvotes,
        'downvotes': newDownvotes,
      };

      if (newStatus != null) {
        incidentUpdate['status'] = newStatus.index;
        incidentUpdate['statusUpdatedAt'] = Timestamp.now();
        incidentUpdate['statusNote'] = 'Auto-updated based on community votes';
      }

      transaction.set(incidentRef, incidentUpdate, SetOptions(merge: true));

      // Update reporter points (only if reporter document exists)
      if (reporterDoc.exists) {
        final reporterData = reporterDoc.data() ?? {};
        final currentPoints = reporterData['points'] ?? 0;
        final pointsDelta = type == VoteType.upvote ? 5 : -3;
        transaction.set(reporterRef, {
          'points': currentPoints + pointsDelta,
        }, SetOptions(merge: true));
      }

      // Increment voter's vote count (only if voter document exists)
      if (voterDoc.exists) {
        final voterData = voterDoc.data() ?? {};
        final currentVotes = voterData['votes'] ?? 0;
        transaction.set(voterRef, {
          'votes': currentVotes + 1,
        }, SetOptions(merge: true));
      }

      return vote;
    });

    // Recalculate reporter's level after transaction completes
    if (result != null) {
      await _userRepository.recalculateReputation(reporterId);
    }

    return result;
  }

  /// Changes an existing vote to a different type.
  Future<VoteModel?> changeVote({
    required String incidentId,
    required String voterId,
    required String reporterId,
    required VoteType newType,
  }) async {
    final voteDocId = '${incidentId}_$voterId';
    final voteRef = _votesCollection.doc(voteDocId);
    final incidentRef = _incidentsCollection.doc(incidentId);
    final reporterRef = _usersCollection.doc(reporterId);

    final result = await _firestore.runTransaction<VoteModel?>((transaction) async {
      // Read all documents first
      final existingVoteDoc = await transaction.get(voteRef);
      final incidentDoc = await transaction.get(incidentRef);
      final reporterDoc = await transaction.get(reporterRef);

      if (!existingVoteDoc.exists) {
        return null;
      }

      final existingVote = VoteModel.fromMap(
        existingVoteDoc.data()!,
        existingVoteDoc.id,
      );

      if (existingVote.type == newType) {
        // Same vote type, no change needed
        return existingVote;
      }

      final updatedVote = existingVote.copyWith(
        type: newType,
        votedAt: DateTime.now(),
      );

      // Update vote document
      transaction.update(voteRef, {
        'type': newType.index,
        'votedAt': Timestamp.fromDate(updatedVote.votedAt),
      });

      // Update incident vote counts
      if (incidentDoc.exists) {
        final incidentData = incidentDoc.data() ?? {};
        final currentUpvotes = incidentData['upvotes'] ?? 0;
        final currentDownvotes = incidentData['downvotes'] ?? 0;
        final currentStatus = IncidentStatus.values[incidentData['status'] ?? 0];

        int newUpvotes;
        int newDownvotes;

        if (newType == VoteType.upvote) {
          // Changed from downvote to upvote
          newUpvotes = currentUpvotes + 1;
          newDownvotes = (currentDownvotes - 1).clamp(0, double.infinity).toInt();
        } else {
          // Changed from upvote to downvote
          newUpvotes = (currentUpvotes - 1).clamp(0, double.infinity).toInt();
          newDownvotes = currentDownvotes + 1;
        }

        // Calculate if status should auto-change
        final newStatus = _calculateAutoStatus(
          upvotes: newUpvotes,
          downvotes: newDownvotes,
          currentStatus: currentStatus,
        );

        final incidentUpdate = <String, dynamic>{
          'upvotes': newUpvotes,
          'downvotes': newDownvotes,
        };

        if (newStatus != null) {
          incidentUpdate['status'] = newStatus.index;
          incidentUpdate['statusUpdatedAt'] = Timestamp.now();
          incidentUpdate['statusNote'] = 'Auto-updated based on community votes';
        }

        transaction.set(incidentRef, incidentUpdate, SetOptions(merge: true));
      }

      // Update reporter points
      if (reporterDoc.exists) {
        final reporterData = reporterDoc.data() ?? {};
        final currentPoints = reporterData['points'] ?? 0;
        // Reverse old vote and apply new: upvote(+5) to downvote(-3) = -8, downvote(-3) to upvote(+5) = +8
        final pointsDelta = newType == VoteType.upvote ? 8 : -8;
        transaction.set(reporterRef, {
          'points': currentPoints + pointsDelta,
        }, SetOptions(merge: true));
      }

      return updatedVote;
    });

    // Recalculate reporter's level after transaction completes
    if (result != null) {
      await _userRepository.recalculateReputation(reporterId);
    }

    return result;
  }

  /// Removes a vote from an incident.
  Future<bool> removeVote({
    required String incidentId,
    required String voterId,
    required String reporterId,
  }) async {
    final voteDocId = '${incidentId}_$voterId';
    final voteRef = _votesCollection.doc(voteDocId);
    final incidentRef = _incidentsCollection.doc(incidentId);
    final reporterRef = _usersCollection.doc(reporterId);
    final voterRef = _usersCollection.doc(voterId);

    final result = await _firestore.runTransaction<bool>((transaction) async {
      // Read all documents first
      final existingVoteDoc = await transaction.get(voteRef);
      final incidentDoc = await transaction.get(incidentRef);
      final reporterDoc = await transaction.get(reporterRef);
      final voterDoc = await transaction.get(voterRef);

      if (!existingVoteDoc.exists) {
        return false;
      }

      final existingVote = VoteModel.fromMap(
        existingVoteDoc.data()!,
        existingVoteDoc.id,
      );

      // Delete vote document
      transaction.delete(voteRef);

      // Reverse the vote counts
      if (incidentDoc.exists) {
        final incidentData = incidentDoc.data() ?? {};
        final currentUpvotes = incidentData['upvotes'] ?? 0;
        final currentDownvotes = incidentData['downvotes'] ?? 0;
        final currentStatus = IncidentStatus.values[incidentData['status'] ?? 0];

        int newUpvotes;
        int newDownvotes;

        if (existingVote.type == VoteType.upvote) {
          newUpvotes = (currentUpvotes - 1).clamp(0, double.infinity).toInt();
          newDownvotes = currentDownvotes;
        } else {
          newUpvotes = currentUpvotes;
          newDownvotes = (currentDownvotes - 1).clamp(0, double.infinity).toInt();
        }

        // Calculate if status should auto-change (e.g., downgrade if upvotes removed)
        final newStatus = _calculateAutoStatus(
          upvotes: newUpvotes,
          downvotes: newDownvotes,
          currentStatus: currentStatus,
        );

        final incidentUpdate = <String, dynamic>{
          'upvotes': newUpvotes,
          'downvotes': newDownvotes,
        };

        if (newStatus != null) {
          incidentUpdate['status'] = newStatus.index;
          incidentUpdate['statusUpdatedAt'] = Timestamp.now();
          incidentUpdate['statusNote'] = 'Auto-updated based on community votes';
        }

        transaction.set(incidentRef, incidentUpdate, SetOptions(merge: true));
      }

      // Reverse reporter points
      if (reporterDoc.exists) {
        final reporterData = reporterDoc.data() ?? {};
        final currentPoints = reporterData['points'] ?? 0;
        final pointsDelta = existingVote.type == VoteType.upvote ? -5 : 3;
        transaction.set(reporterRef, {
          'points': currentPoints + pointsDelta,
        }, SetOptions(merge: true));
      }

      // Decrement voter's vote count
      if (voterDoc.exists) {
        final voterData = voterDoc.data() ?? {};
        final currentVotes = voterData['votes'] ?? 0;
        transaction.set(voterRef, {
          'votes': (currentVotes - 1).clamp(0, double.infinity).toInt(),
        }, SetOptions(merge: true));
      }

      return true;
    });

    // Recalculate reporter's level after transaction completes
    if (result) {
      await _userRepository.recalculateReputation(reporterId);
    }

    return result;
  }

  /// Gets the user's vote for a specific incident.
  Future<VoteModel?> getUserVote(String incidentId, String voterId) async {
    final voteDocId = '${incidentId}_$voterId';
    final doc = await _votesCollection.doc(voteDocId).get();

    if (doc.exists && doc.data() != null) {
      return VoteModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  /// Gets all votes by a user.
  Future<List<VoteModel>> getVotesByUser(String voterId) async {
    final snapshot = await _votesCollection
        .where('voterId', isEqualTo: voterId)
        .get();

    return snapshot.docs
        .map((doc) => VoteModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Gets all votes for an incident.
  Future<List<VoteModel>> getVotesForIncident(String incidentId) async {
    final snapshot = await _votesCollection
        .where('incidentId', isEqualTo: incidentId)
        .get();

    return snapshot.docs
        .map((doc) => VoteModel.fromMap(doc.data(), doc.id))
        .toList();
  }
}
