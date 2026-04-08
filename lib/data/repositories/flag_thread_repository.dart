import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/flag_message_model.dart';
import '../models/flag_thread_model.dart';

class FlagThreadRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _threads =>
      _db.collection('flag_threads');

  CollectionReference<Map<String, dynamic>> _messages(String flagId) =>
      _threads.doc(flagId).collection('messages');

  // ── Thread operations ──────────────────────────────────────────────────────

  /// Creates thread doc if it doesn't exist. Safe to call multiple times.
  Future<void> ensureThread(
      String flagId, List<String> participants) async {
    final ref = _threads.doc(flagId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        tx.set(ref, FlagThreadModel(
          flagId: flagId,
          participants: participants,
          createdAt: DateTime.now(),
        ).toMap());
      } else {
        // Merge any new participants not already in the list.
        final existing =
            List<String>.from(snap.data()?['participants'] ?? []);
        final merged = {...existing, ...participants}.toList();
        if (merged.length != existing.length) {
          tx.update(ref, {'participants': merged});
        }
      }
    });
  }

  Stream<FlagThreadModel?> watchThread(String flagId) {
    return _threads.doc(flagId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return FlagThreadModel.fromMap(snap.data()!);
    });
  }

  Stream<List<FlagMessageModel>> watchMessages(String flagId) {
    return _messages(flagId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FlagMessageModel.fromMap(d.data(), d.id))
            .toList());
  }

  /// Returns threads where the user is a participant, newest first.
  /// Sorts client-side to avoid a composite index requirement and to handle
  /// threads where lastMessageAt is null (thread exists but no messages yet).
  Stream<List<FlagThreadModel>> watchUserThreads(String userId) {
    return _threads
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snap) {
          final threads = snap.docs
              .map((d) => FlagThreadModel.fromMap(d.data()))
              .toList();
          threads.sort((a, b) {
            final aTime = a.lastMessageAt ?? a.createdAt;
            final bTime = b.lastMessageAt ?? b.createdAt;
            return bTime.compareTo(aTime);
          });
          return threads;
        });
  }

  // ── Message operations ─────────────────────────────────────────────────────

  Future<void> sendMessage(
    String flagId,
    FlagMessageModel message,
    List<String> participants,
  ) async {
    final threadRef = _threads.doc(flagId);
    final msgRef = _messages(flagId).doc();

    await _db.runTransaction((tx) async {
      final threadSnap = await tx.get(threadRef);

      // Ensure thread exists (in case first message).
      final merged = threadSnap.exists
          ? {...List<String>.from(threadSnap.data()?['participants'] ?? []),
              ...participants,
              message.senderId}
              .toList()
          : {...participants, message.senderId}.toList();

      // Build unread increment map — everyone except sender.
      final Map<String, dynamic> unreadUpdate = {};
      for (final uid in merged) {
        if (uid != message.senderId) {
          unreadUpdate['unreadCounts.$uid'] = FieldValue.increment(1);
        }
      }

      // Write message.
      tx.set(msgRef, message.toMap());

      // Update / create thread metadata.
      final preview = message.content.length > 80
          ? '${message.content.substring(0, 80)}…'
          : message.content;

      if (threadSnap.exists) {
        tx.update(threadRef, {
          'participants': merged,
          'lastMessage': preview,
          'lastMessageAt': Timestamp.fromDate(message.createdAt),
          'lastSenderId': message.senderId,
          ...unreadUpdate,
        });
      } else {
        tx.set(threadRef, {
          'flagId': flagId,
          'participants': merged,
          'lastMessage': preview,
          'lastMessageAt': Timestamp.fromDate(message.createdAt),
          'lastSenderId': message.senderId,
          'unreadCounts': {
            for (final uid in merged)
              if (uid != message.senderId) uid: 1,
          },
          'createdAt': Timestamp.fromDate(message.createdAt),
        });
      }
    });
  }

  /// Resets the unread count for [userId] to 0.
  Future<void> markRead(String flagId, String userId) async {
    await _threads.doc(flagId).update({'unreadCounts.$userId': 0});
  }

  /// Marks the thread as closed so no further messages can be sent.
  Future<void> markClosed(String flagId) async {
    await _threads.doc(flagId).set(
      {'closedAt': Timestamp.now()},
      SetOptions(merge: true),
    );
  }
}
