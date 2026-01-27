import 'package:flutter/foundation.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/user_repository.dart';

class UserProvider extends ChangeNotifier {
  final UserRepository _repository = UserRepository();

  UserModel? get currentUser => _repository.getCurrentUser();

  void updateUser(UserModel user) {
    _repository.updateUser(user);
    notifyListeners();
  }
}
