import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/flag_message_model.dart';
import '../../data/models/flag_thread_model.dart';
import '../../data/repositories/flag_thread_repository.dart';

class FlagThreadProvider extends ChangeNotifier {
  final FlagThreadRepository _repository = FlagThreadRepository();

  // Active thread (open dialog / screen)
  String? _activeFlagId;
  List<FlagMessageModel> _messages = [];
  StreamSubscription? _messagesSub;
  StreamSubscription? _threadDocSub;
  bool _isActiveClosed = false;
  bool _isLoading = false;
  String? _error;

  // Reporter inbox — all threads the user participates in
  List<FlagThreadModel> _userThreads = [];
  StreamSubscription? _threadsSub;
  String? _inboxUserId;

  // Getters
  String? get activeFlagId => _activeFlagId;
  List<FlagMessageModel> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<FlagThreadModel> get userThreads => _userThreads;
  bool get isActiveClosed => _isActiveClosed;

  int get totalUnread {
    if (_inboxUserId == null) return 0;
    return _userThreads
        .where((t) => !t.isClosed)
        .fold(0, (sum, t) => sum + t.unreadFor(_inboxUserId!));
  }

  int unreadForFlag(String flagId) {
    if (_inboxUserId == null) return 0;
    final thread = _userThreads.cast<FlagThreadModel?>().firstWhere(
          (t) => t?.flagId == flagId,
          orElse: () => null,
        );
    if (thread == null || thread.isClosed) return 0;
    return thread.unreadFor(_inboxUserId!);
  }

  // ── Active thread ──────────────────────────────────────────────────────────

  void openThread(
    String flagId,
    List<String> participants,
    String currentUserId, {
    bool initialClosed = false,
  }) {
    if (_activeFlagId == flagId) return;
    _activeFlagId = flagId;
    _messages = [];
    _isLoading = true;
    _isActiveClosed = initialClosed;
    notifyListeners();

    _messagesSub?.cancel();
    _messagesSub = _repository.watchMessages(flagId).listen(
      (msgs) {
        _messages = msgs;
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

    // Watch thread doc for real-time closed status.
    _threadDocSub?.cancel();
    _threadDocSub = _repository.watchThread(flagId).listen((thread) {
      _isActiveClosed = thread?.isClosed ?? false;
      notifyListeners();
    });

    // Always include the opener in participants so they receive future unread notifications.
    final allParticipants = {
      ...participants,
      if (currentUserId.isNotEmpty) currentUserId,
    }.where((id) => id.isNotEmpty).toList();

    // Ensure thread doc exists and mark read.
    _repository.ensureThread(flagId, allParticipants).then((_) {
      _repository.markRead(flagId, currentUserId);
    });
  }

  void closeThread() {
    _messagesSub?.cancel();
    _messagesSub = null;
    _threadDocSub?.cancel();
    _threadDocSub = null;
    _activeFlagId = null;
    _messages = [];
    _isActiveClosed = false;
    notifyListeners();
  }

  Future<void> sendMessage({
    required String flagId,
    required String content,
    required String senderId,
    required String senderName,
    required String senderRole,
    required List<String> participants,
  }) async {
    final message = FlagMessageModel(
      id: '',
      flagId: flagId,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      content: content.trim(),
      createdAt: DateTime.now(),
    );
    try {
      await _repository.sendMessage(flagId, message, participants);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> markRead(String flagId, String userId) async {
    try {
      await _repository.markRead(flagId, userId);
    } catch (_) {}
  }

  Future<void> closeActiveThread() async {
    if (_activeFlagId == null) return;
    try {
      await _repository.markClosed(_activeFlagId!);
    } catch (_) {}
  }

  // ── Reporter inbox ─────────────────────────────────────────────────────────

  void loadUserThreads(String userId) {
    _inboxUserId = userId;
    _threadsSub?.cancel();
    _threadsSub = _repository.watchUserThreads(userId).listen(
      (threads) {
        _userThreads = threads;
        notifyListeners();
      },
      onError: (_) {},
    );
  }

  void stopUserThreads() {
    _threadsSub?.cancel();
    _threadsSub = null;
    _userThreads = [];
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _threadDocSub?.cancel();
    _threadsSub?.cancel();
    super.dispose();
  }
}
