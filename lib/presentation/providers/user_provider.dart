import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/services/media_upload_service.dart';

class UserProvider extends ChangeNotifier {
  final UserRepository _repository = UserRepository();
  final MediaUploadService _mediaService = MediaUploadService();

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

  Future<UserModel?> getUserById(String uid) async {
    return await _repository.getCurrentUser(uid);
  }

  Future<Map<String, UserModel?>> getUsersByIds(List<String> ids) async {
    final results = await Future.wait(
      ids.map((id) => _repository.getCurrentUser(id)),
    );
    return Map.fromIterables(ids, results);
  }

  Future<void> updateLocation(double latitude, double longitude) async {
    if (_currentUser == null) return;
    try {
      await _repository.updateUserLocation(_currentUser!.id, latitude, longitude);
    } catch (e) {
      if (kDebugMode) debugPrint('UserProvider: updateLocation failed: $e');
    }
  }

  void clearUser() {
    _currentUser = null;
    _error = null;
    notifyListeners();
  }

  /// Refresh current user data (call after reputation-affecting actions)
  Future<void> refreshCurrentUser() async {
    if (_currentUser == null) return;

    try {
      _currentUser = await _repository.getCurrentUser(_currentUser!.id);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<XFile?> pickProfilePhoto({ImageSource source = ImageSource.gallery}) async {
    return await _mediaService.pickProfilePhoto(source: source);
  }

  Future<bool> uploadProfilePhoto(XFile file) async {
    if (_currentUser == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final url = await _mediaService.uploadProfilePhoto(_currentUser!.id, file);

      if (url != null) {
        await _repository.updateProfilePhoto(_currentUser!.id, url);
        _currentUser = _currentUser!.copyWith(profilePhotoUrl: url);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('uploadProfilePhoto: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeProfilePhoto() async {
    if (_currentUser == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      await _mediaService.deleteProfilePhoto(_currentUser!.id);
      await _repository.updateProfilePhoto(_currentUser!.id, null);
      _currentUser = _currentUser!.copyWith(clearProfilePhoto: true);
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
}
