import 'package:flutter/material.dart';

class CategoryModel {
  final String id;
  final String name;
  final String iconName;
  final String colorHex;
  final bool isEnabled;
  final bool isDefault; // Default categories can't be deleted, only disabled
  final int sortOrder;

  CategoryModel({
    required this.id,
    required this.name,
    required this.iconName,
    required this.colorHex,
    this.isEnabled = true,
    this.isDefault = false,
    this.sortOrder = 0,
  });

  IconData get icon {
    switch (iconName) {
      case 'shield':
        return Icons.shield;
      case 'construction':
        return Icons.construction;
      case 'visibility':
        return Icons.visibility;
      case 'directions_car':
        return Icons.directions_car;
      case 'eco':
        return Icons.eco;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'warning':
        return Icons.warning;
      case 'report':
        return Icons.report;
      case 'security':
        return Icons.security;
      case 'flash_on':
        return Icons.flash_on;
      case 'water_drop':
        return Icons.water_drop;
      case 'pets':
        return Icons.pets;
      default:
        return Icons.category;
    }
  }

  Color get color {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'iconName': iconName,
      'colorHex': colorHex,
      'isEnabled': isEnabled,
      'isDefault': isDefault,
      'sortOrder': sortOrder,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map, String id) {
    return CategoryModel(
      id: id,
      name: map['name'] ?? '',
      iconName: map['iconName'] ?? 'category',
      colorHex: map['colorHex'] ?? '#808080',
      isEnabled: map['isEnabled'] ?? true,
      isDefault: map['isDefault'] ?? false,
      sortOrder: map['sortOrder'] ?? 0,
    );
  }

  CategoryModel copyWith({
    String? id,
    String? name,
    String? iconName,
    String? colorHex,
    bool? isEnabled,
    bool? isDefault,
    int? sortOrder,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      colorHex: colorHex ?? this.colorHex,
      isEnabled: isEnabled ?? this.isEnabled,
      isDefault: isDefault ?? this.isDefault,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  // Default categories that match the original enum
  static List<CategoryModel> get defaultCategories => [
        CategoryModel(
          id: 'crime',
          name: 'Crime',
          iconName: 'shield',
          colorHex: '#E53E3E',
          isDefault: true,
          sortOrder: 0,
        ),
        CategoryModel(
          id: 'infrastructure',
          name: 'Infrastructure',
          iconName: 'construction',
          colorHex: '#3182CE',
          isDefault: true,
          sortOrder: 1,
        ),
        CategoryModel(
          id: 'suspicious',
          name: 'Suspicious',
          iconName: 'visibility',
          colorHex: '#805AD5',
          isDefault: true,
          sortOrder: 2,
        ),
        CategoryModel(
          id: 'traffic',
          name: 'Traffic',
          iconName: 'directions_car',
          colorHex: '#DD6B20',
          isDefault: true,
          sortOrder: 3,
        ),
        CategoryModel(
          id: 'environmental',
          name: 'Environmental',
          iconName: 'eco',
          colorHex: '#38A169',
          isDefault: true,
          sortOrder: 4,
        ),
        CategoryModel(
          id: 'emergency',
          name: 'Emergency',
          iconName: 'local_hospital',
          colorHex: '#E53E3E',
          isDefault: true,
          sortOrder: 5,
        ),
      ];

  // Available icons for custom categories
  static List<String> get availableIcons => [
        'shield',
        'construction',
        'visibility',
        'directions_car',
        'eco',
        'local_hospital',
        'warning',
        'report',
        'security',
        'flash_on',
        'water_drop',
        'pets',
        'category',
      ];

  // Available colors for custom categories
  static List<String> get availableColors => [
        '#E53E3E', // Red
        '#DD6B20', // Orange
        '#D69E2E', // Yellow
        '#38A169', // Green
        '#319795', // Teal
        '#3182CE', // Blue
        '#5A67D8', // Indigo
        '#805AD5', // Purple
        '#D53F8C', // Pink
        '#718096', // Gray
      ];
}
