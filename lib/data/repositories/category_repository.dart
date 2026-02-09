import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category_model.dart';

class CategoryRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _categoriesCollection =>
      _firestore.collection('categories');

  /// Initialize default categories if they don't exist
  Future<void> initializeDefaultCategories() async {
    final snapshot = await _categoriesCollection.get();
    if (snapshot.docs.isEmpty) {
      // No categories exist, create defaults
      for (final category in CategoryModel.defaultCategories) {
        await _categoriesCollection.doc(category.id).set(category.toMap());
      }
    }
  }

  /// Stream all categories
  Stream<List<CategoryModel>> watchAll() {
    return _categoriesCollection
        .orderBy('sortOrder')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CategoryModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Stream only enabled categories
  Stream<List<CategoryModel>> watchEnabled() {
    return _categoriesCollection
        .where('isEnabled', isEqualTo: true)
        .orderBy('sortOrder')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CategoryModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Get all categories
  Future<List<CategoryModel>> getAll() async {
    final snapshot = await _categoriesCollection.orderBy('sortOrder').get();
    return snapshot.docs
        .map((doc) => CategoryModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Get only enabled categories
  Future<List<CategoryModel>> getEnabled() async {
    final snapshot = await _categoriesCollection
        .where('isEnabled', isEqualTo: true)
        .orderBy('sortOrder')
        .get();
    return snapshot.docs
        .map((doc) => CategoryModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Get category by ID
  Future<CategoryModel?> getById(String id) async {
    final doc = await _categoriesCollection.doc(id).get();
    if (doc.exists && doc.data() != null) {
      return CategoryModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  /// Add a new category
  Future<String> add(CategoryModel category) async {
    final docRef = await _categoriesCollection.add(category.toMap());
    return docRef.id;
  }

  /// Update a category
  Future<void> update(CategoryModel category) async {
    await _categoriesCollection.doc(category.id).update(category.toMap());
  }

  /// Toggle category enabled status
  Future<void> toggleEnabled(String id, bool isEnabled) async {
    await _categoriesCollection.doc(id).update({'isEnabled': isEnabled});
  }

  /// Delete a category (only non-default categories)
  Future<void> delete(String id) async {
    final doc = await _categoriesCollection.doc(id).get();
    if (doc.exists && doc.data() != null) {
      final category = CategoryModel.fromMap(doc.data()!, doc.id);
      if (!category.isDefault) {
        await _categoriesCollection.doc(id).delete();
      }
    }
  }

  /// Update sort order for all categories
  Future<void> updateSortOrders(List<CategoryModel> categories) async {
    final batch = _firestore.batch();
    for (int i = 0; i < categories.length; i++) {
      batch.update(_categoriesCollection.doc(categories[i].id), {
        'sortOrder': i,
      });
    }
    await batch.commit();
  }
}
