import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/system_config_model.dart';
import '../../data/repositories/system_config_repository.dart';

class SystemConfigProvider extends ChangeNotifier {
  final SystemConfigRepository _repository = SystemConfigRepository();

  SystemConfigModel _config = SystemConfigModel.defaults;
  SystemConfigModel get config => _config;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  StreamSubscription? _subscription;

  void startListening() {
    if (_subscription != null) return; // already listening
    _isLoading = true;
    notifyListeners();
    _subscription = _repository.watch().listen(
      (config) {
        _config = config;
        // Keep static cache up-to-date for VoteRepository / UserRepository
        SystemConfigRepository.updateCache(config);
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

  Future<bool> updateFields(
      Map<String, dynamic> fields, String updatedBy) async {
    try {
      await _repository.updateFields(fields, updatedBy);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> saveConfig(SystemConfigModel config, String updatedBy) async {
    try {
      await _repository.save(config, updatedBy);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
