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

  List<FlagModel> get flags => _flags;
  List<FlagModel> get pendingFlags => _pendingFlags;
  int get pendingCount => _pendingCount;
  bool get isLoading => _isLoading;
  String? get error => _error;

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
        _pendingCount = flags.length;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _flagsSubscription?.cancel();
    _pendingSubscription?.cancel();
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
      _pendingCount = _pendingFlags.length;
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
      // Update local list
      _flags = _flags.map((f) {
        if (f.id == id) {
          return f.copyWith(
            status: FlagStatus.resolved,
            resolvedAt: DateTime.now(),
            resolvedBy: resolvedBy,
            resolutionNote: note,
          );
        }
        return f;
      }).toList();
      _pendingFlags.removeWhere((f) => f.id == id);
      _pendingCount = _pendingFlags.length;
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
      // Update local list
      _flags = _flags.map((f) {
        if (f.id == id) {
          return f.copyWith(
            status: FlagStatus.dismissed,
            resolvedAt: DateTime.now(),
            resolvedBy: resolvedBy,
            resolutionNote: note,
          );
        }
        return f;
      }).toList();
      _pendingFlags.removeWhere((f) => f.id == id);
      _pendingCount = _pendingFlags.length;
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
      // Update local list
      _flags = _flags.map((f) {
        if (f.id == id) {
          return f.copyWith(
            status: FlagStatus.reviewed,
            resolvedAt: DateTime.now(),
            resolvedBy: resolvedBy,
          );
        }
        return f;
      }).toList();
      _pendingFlags.removeWhere((f) => f.id == id);
      _pendingCount = _pendingFlags.length;
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
