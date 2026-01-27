import '../models/user_model.dart';

class UserRepository {
  UserModel? _currentUser;

  UserRepository() {
    _currentUser = UserModel(
      id: 'user1',
      name: 'Jane Doe',
      handle: '@janedoe',
      memberSince: DateTime(2025, 1, 1),
      reports: 24,
      votes: 156,
      points: 850,
      level: 4,
      levelTitle: 'Guardian',
      isTrusted: true,
    );
  }

  UserModel? getCurrentUser() => _currentUser;

  void updateUser(UserModel user) {
    _currentUser = user;
  }
}
