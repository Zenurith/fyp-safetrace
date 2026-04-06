import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/flag_model.dart';
import '../../data/repositories/flag_repository.dart';

class FlagProvider extends ChangeNotifier {
  final FlagRepository _repository = FlagRepository();

  List<FlagModel> _flags = [];
  List<FlagModel> _pendingFlags = [];
  int _pendingCount = 0;
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _flagsSubscription;
  StreamSubscription? _pendingSubscription;

  List<FlagModel> _communityFlags = [];
  int _communityPendingCount = 0;
  StreamSubscription? _communityFlagsSubscription;
  String? _activeCommunityId;

  List<FlagModel> get flags => _flags;
  List<FlagModel> get pendingFlags => _pendingFlags;
  int get pendingCount => _pendingCount;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<FlagModel> get communityFlags => _communityFlags;
  int get communityPendingCount => _communityPendingCount;

  /// User-type flags that community staff have escalated to system admin
  /// and are still awaiting admin action (status == reviewed).
  List<FlagModel> get escalatedFlags => _flags
      .where((f) =>
          f.escalatedToAdmin && f.status == FlagStatus.reviewed)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Combined count for the admin sidebar badge.
  /// Derived from _flags so it stays in sync with what the page shows.
  int get totalAdminPendingCount {
    final communityPending = _flags
        .where((f) =>
            f.targetType == FlagTargetType.community &&
            f.status == FlagStatus.pending)
        .length;
    return communityPending + escalatedFlags.length;
  }

  void startListening() {
    _flagsSubscription?.cancel();
    _flagsSubscription = _repository.watchAll().listen(
      (flags) {
        _flags = flags;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  void startListeningPending() {
    _pendingSubscription?.cancel();
    _pendingSubscription = _repository.watchPending().listen(
      (flags) {
        _pendingFlags = flags;
        // Admin flags page only shows community flags — count only those so the
        // sidebar badge matches what's actually visible and actionable.
        _pendingCount =
            flags.where((f) => f.targetType == FlagTargetType.community).length;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  void startListeningFlagsByCommunity(String communityId) {
    // Always restart the subscription — this ensures a fresh server connection
    // even if the same communityId was already active (e.g. after a reconnect).
    _communityFlagsSubscription?.cancel();
    _activeCommunityId = communityId;
    _communityFlagsSubscription =
        _repository.watchFlagsByCommunity(communityId).listen(
      (flags) {
        _communityFlags = flags;
        _communityPendingCount =
            flags.where((f) => f.status == FlagStatus.pending).length;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
        // Auto-reconnect after stream error so manager B stays in sync
        Future.delayed(const Duration(seconds: 3), () {
          if (_activeCommunityId == communityId) {
            startListeningFlagsByCommunity(communityId);
          }
        });
      },
    );
  }

  void stopListeningCommunityFlags() {
    _communityFlagsSubscription?.cancel();
    _communityFlagsSubscription = null;
    _activeCommunityId = null;
    _communityFlags = [];
    _communityPendingCount = 0;
  }

  /// Force-fetch the latest flags directly from Firestore, bypassing the
  /// stream cache. Useful for pull-to-refresh.
  Future<void> refreshCommunityFlags() async {
    if (_activeCommunityId == null) return;
    try {
      final flags =
          await _repository.getFlagsByCommunity(_activeCommunityId!);
      _communityFlags = flags;
      _communityPendingCount =
          flags.where((f) => f.status == FlagStatus.pending).length;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> refreshCommunityPendingCount(String communityId) async {
    try {
      _communityPendingCount =
          await _repository.getPendingFlagCountByCommunity(communityId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _flagsSubscription?.cancel();
    _pendingSubscription?.cancel();
    _communityFlagsSubscription?.cancel();
    super.dispose();
  }

  Future<void> loadFlags() async {
    _isLoading = true;
    notifyListeners();

    try {
      _flags = await _repository.getAll();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadPendingFlags() async {
    _isLoading = true;
    notifyListeners();

    try {
      _pendingFlags = await _repository.getPending();
      _pendingCount =
          _pendingFlags.where((f) => f.targetType == FlagTargetType.community).length;
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshPendingCount() async {
    try {
      _pendingCount = await _repository.getPendingCount();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> resolveFlag(String id, {String? resolvedBy, String? note}) async {
    try {
      await _repository.updateStatus(
        id,
        FlagStatus.resolved,
        resolvedBy: resolvedBy,
        resolutionNote: note,
      );
      final idx = _flags.indexWhere((f) => f.id == id);
      if (idx != -1) {
        _flags[idx] = _flags[idx].copyWith(
          status: FlagStatus.resolved,
          resolvedAt: DateTime.now(),
          resolvedBy: resolvedBy,
          resolutionNote: note,
        );
      }
      _pendingFlags.removeWhere((f) => f.id == id);
      _pendingCount = _pendingFlags.length;
      final cidx = _communityFlags.indexWhere((f) => f.id == id);
      if (cidx != -1) {
        _communityFlags[cidx] = _communityFlags[cidx].copyWith(
          status: FlagStatus.resolved,
          resolvedAt: DateTime.now(),
          resolvedBy: resolvedBy,
          resolutionNote: note,
        );
        _communityPendingCount =
            _communityFlags.where((f) => f.status == FlagStatus.pending).length;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> dismissFlag(String id, {String? resolvedBy, String? note}) async {
    try {
      await _repository.updateStatus(
        id,
        FlagStatus.dismissed,
        resolvedBy: resolvedBy,
        resolutionNote: note,
      );
      final idx = _flags.indexWhere((f) => f.id == id);
      if (idx != -1) {
        _flags[idx] = _flags[idx].copyWith(
          status: FlagStatus.dismissed,
          resolvedAt: DateTime.now(),
          resolvedBy: resolvedBy,
          resolutionNote: note,
        );
      }
      _pendingFlags.removeWhere((f) => f.id == id);
      _pendingCount = _pendingFlags.length;
      final cidx = _communityFlags.indexWhere((f) => f.id == id);
      if (cidx != -1) {
        _communityFlags[cidx] = _communityFlags[cidx].copyWith(
          status: FlagStatus.dismissed,
          resolvedAt: DateTime.now(),
          resolvedBy: resolvedBy,
          resolutionNote: note,
        );
        _communityPendingCount =
            _communityFlags.where((f) => f.status == FlagStatus.pending).length;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> markAsReviewed(String id, {String? resolvedBy}) async {
    try {
      await _repository.updateStatus(
        id,
        FlagStatus.reviewed,
        resolvedBy: resolvedBy,
      );
      final idx = _flags.indexWhere((f) => f.id == id);
      if (idx != -1) {
        _flags[idx] = _flags[idx].copyWith(
          status: FlagStatus.reviewed,
          resolvedAt: DateTime.now(),
          resolvedBy: resolvedBy,
        );
      }
      _pendingFlags.removeWhere((f) => f.id == id);
      _pendingCount = _pendingFlags.length;
      final cidx = _communityFlags.indexWhere((f) => f.id == id);
      if (cidx != -1) {
        _communityFlags[cidx] = _communityFlags[cidx].copyWith(
          status: FlagStatus.reviewed,
          resolvedAt: DateTime.now(),
          resolvedBy: resolvedBy,
        );
        _communityPendingCount =
            _communityFlags.where((f) => f.status == FlagStatus.pending).length;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> escalateToAdmin(
    String id, {
    required String escalatedBy,
    String? note,
  }) async {
    try {
      await _repository.escalate(id, escalatedBy: escalatedBy, note: note);
      final now = DateTime.now();
      void patchList(List<FlagModel> list) {
        final idx = list.indexWhere((f) => f.id == id);
        if (idx != -1) {
          list[idx] = list[idx].copyWith(
            status: FlagStatus.reviewed,
            escalatedToAdmin: true,
            escalatedBy: escalatedBy,
            resolvedAt: now,
            resolvedBy: escalatedBy,
            resolutionNote: note,
          );
        }
      }
      patchList(_flags);
      patchList(_communityFlags);
      _pendingFlags.removeWhere((f) => f.id == id);
      _pendingCount =
          _pendingFlags.where((f) => f.targetType == FlagTargetType.community).length;
      _communityPendingCount =
          _communityFlags.where((f) => f.status == FlagStatus.pending).length;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  List<FlagModel> getFilteredFlags(FlagStatus? status) {
    if (status == null) return _flags;
    return _flags.where((f) => f.status == status).toList();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
