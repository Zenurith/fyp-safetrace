import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  Future<void> createUser(String uid, String name, String handle) async {
    final user = UserModel(
      id: uid,
      name: name,
      handle: handle,
      memberSince: DateTime.now(),
    );
    await _usersCollection.doc(uid).set(user.toMap());
  }

  Future<UserModel?> getCurrentUser(String uid) async {
    final doc = await _usersCollection.doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  Future<void> updateUser(UserModel user) async {
    await _usersCollection.doc(user.id).update(user.toMap());
  }

  Future<List<UserModel>> getAllUsers() async {
    final snapshot = await _usersCollection.get();
    return snapshot.docs
        .map((doc) => UserModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> updateUserRole(String uid, String role) async {
    await _usersCollection.doc(uid).update({'role': role});
  }

  Future<void> updateProfilePhoto(String uid, String? photoUrl) async {
    await _usersCollection.doc(uid).update({'profilePhotoUrl': photoUrl});
  }
}
