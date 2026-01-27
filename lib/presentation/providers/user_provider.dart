import 'package:flutter/foundation.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/user_repository.dart';

class UserProvider extends ChangeNotifier {
  final UserRepository _repository = UserRepository();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadUser(String uid) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentUser = await _repository.getCurrentUser(uid);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createUser(String uid, String name, String handle) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.createUser(uid, name, handle);
      _currentUser = await _repository.getCurrentUser(uid);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadOrCreateUser(String uid, String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentUser = await _repository.getCurrentUser(uid);
      if (_currentUser == null) {
        // Auth account exists but no Firestore doc — create one with defaults
        final name = email.split('@').first;
        await _repository.createUser(uid, name, '@$name');
        _currentUser = await _repository.getCurrentUser(uid);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUser(UserModel user) async {
    try {
      await _repository.updateUser(user);
      _currentUser = user;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<List<UserModel>> fetchAllUsers() async {
    return await _repository.getAllUsers();
  }

  Future<void> setUserRole(String uid, String role) async {
    await _repository.updateUserRole(uid, role);
  }

  void clearUser() {
    _currentUser = null;
    _error = null;
    notifyListeners();
  }
}
