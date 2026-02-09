import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/category_model.dart';
import '../../data/repositories/category_repository.dart';

class CategoryProvider extends ChangeNotifier {
  final CategoryRepository _repository = CategoryRepository();

  List<CategoryModel> _categories = [];
  List<CategoryModel> get categories => _categories;

  List<CategoryModel> get enabledCategories =>
      _categories.where((c) => c.isEnabled).toList();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  StreamSubscription? _subscription;

  /// Initialize and start listening to categories
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Initialize default categories if needed
      await _repository.initializeDefaultCategories();

      // Start listening to changes
      _subscription = _repository.watchAll().listen(
        (categories) {
          _categories = categories;
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
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a new category
  Future<String?> addCategory({
    required String name,
    required String iconName,
    required String colorHex,
  }) async {
    try {
      final sortOrder = _categories.isEmpty
          ? 0
          : _categories.map((c) => c.sortOrder).reduce((a, b) => a > b ? a : b) + 1;

      final category = CategoryModel(
        id: '', // Will be assigned by Firestore
        name: name,
        iconName: iconName,
        colorHex: colorHex,
        isEnabled: true,
        isDefault: false,
        sortOrder: sortOrder,
      );

      return await _repository.add(category);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Update a category
  Future<bool> updateCategory(CategoryModel category) async {
    try {
      await _repository.update(category);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Toggle category enabled status
  Future<bool> toggleCategoryEnabled(String id) async {
    try {
      final category = _categories.firstWhere((c) => c.id == id);
      await _repository.toggleEnabled(id, !category.isEnabled);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Delete a category
  Future<bool> deleteCategory(String id) async {
    try {
      final category = _categories.firstWhere((c) => c.id == id);
      if (category.isDefault) {
        _error = 'Cannot delete default categories';
        notifyListeners();
        return false;
      }
      await _repository.delete(id);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Get category by ID
  CategoryModel? getCategoryById(String id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get category by name (case insensitive)
  CategoryModel? getCategoryByName(String name) {
    try {
      return _categories.firstWhere(
          (c) => c.name.toLowerCase() == name.toLowerCase());
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
