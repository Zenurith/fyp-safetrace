import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/category_model.dart';
import '../../../utils/app_theme.dart';
import '../../providers/category_provider.dart';

class AdminCategoriesTab extends StatelessWidget {
  const AdminCategoriesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final categories = categoryProvider.categories;

    if (categoryProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (categoryProvider.error != null) {
      return Center(
        child: Text(
          'Error loading categories',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      body: categories.isEmpty
          ? Center(
              child: Text(
                'No categories found',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _CategoryCard(category: categories[index]),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategoryDialog(context),
        backgroundColor: AppTheme.primaryRed,
        elevation: 0,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _CategoryDialog(
        onSave: (name, iconName, colorHex) async {
          final result = await context.read<CategoryProvider>().addCategory(
                name: name,
                iconName: iconName,
                colorHex: colorHex,
              );
          if (result != null && context.mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Category "$name" added'),
              backgroundColor: AppTheme.successGreen,
            ));
          }
        },
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final CategoryModel category;

  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: category.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(category.icon, color: category.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(category.name, style: AppTheme.headingSmall),
                    if (category.isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundGrey,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Default',
                          style: AppTheme.caption.copyWith(fontSize: 10),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  category.isEnabled ? 'Enabled' : 'Disabled',
                  style: AppTheme.caption.copyWith(
                    color: category.isEnabled
                        ? AppTheme.successGreen
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: category.isEnabled,
            activeTrackColor: AppTheme.successGreen,
            onChanged: (value) {
              context.read<CategoryProvider>().toggleCategoryEnabled(category.id);
            },
          ),
          if (!category.isDefault) ...[
            _ActionButton(
              icon: Icons.edit_outlined,
              onTap: () => _showEditDialog(context),
            ),
            const SizedBox(width: 4),
            _ActionButton(
              icon: Icons.delete_outline,
              color: AppTheme.primaryRed,
              onTap: () => _showDeleteDialog(context),
            ),
          ],
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _CategoryDialog(
        category: category,
        onSave: (name, iconName, colorHex) async {
          final updated = category.copyWith(
            name: name,
            iconName: iconName,
            colorHex: colorHex,
          );
          final result =
              await context.read<CategoryProvider>().updateCategory(updated);
          if (result && context.mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Category "$name" updated'),
              backgroundColor: AppTheme.successGreen,
            ));
          }
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text('Delete Category', style: AppTheme.headingMedium),
        content: Text(
          'Are you sure you want to delete "${category.name}"?',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style:
                    AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              final result = await context
                  .read<CategoryProvider>()
                  .deleteCategory(category.id);
              if (result && context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Category "${category.name}" deleted'),
                  backgroundColor: AppTheme.successGreen,
                ));
              }
            },
            child: Text('Delete',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.primaryRed)),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Icon(icon, size: 18, color: color ?? AppTheme.primaryDark),
      ),
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  final CategoryModel? category;
  final Function(String name, String iconName, String colorHex) onSave;

  const _CategoryDialog({this.category, required this.onSave});

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late TextEditingController _nameController;
  late String _selectedIcon;
  late String _selectedColor;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.category?.name ?? '');
    _selectedIcon = widget.category?.iconName ?? 'category';
    _selectedColor = widget.category?.colorHex ?? '#3182CE';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  IconData _getIconData(String iconName) {
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

  Color _getColor(String colorHex) {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.category != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Text(
        isEditing ? 'Edit Category' : 'Add Category',
        style: AppTheme.headingMedium,
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                style: AppTheme.bodyMedium,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Category Name',
                  labelStyle: AppTheme.caption,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Icon', style: AppTheme.headingSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CategoryModel.availableIcons.map((iconName) {
                  final isSelected = _selectedIcon == iconName;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = iconName),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _getColor(_selectedColor).withValues(alpha: 0.1)
                            : AppTheme.backgroundGrey,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? _getColor(_selectedColor)
                              : AppTheme.cardBorder,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Icon(
                        _getIconData(iconName),
                        color: isSelected
                            ? _getColor(_selectedColor)
                            : AppTheme.textSecondary,
                        size: 22,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text('Color', style: AppTheme.headingSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CategoryModel.availableColors.map((colorHex) {
                  final isSelected = _selectedColor == colorHex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = colorHex),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _getColor(colorHex),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryDark
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundGrey,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getColor(_selectedColor).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getIconData(_selectedIcon),
                        color: _getColor(_selectedColor),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _nameController.text.isEmpty
                          ? 'Preview'
                          : _nameController.text,
                      style: AppTheme.headingSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _nameController.text.trim().isEmpty
              ? null
              : () => widget.onSave(
                    _nameController.text.trim(),
                    _selectedIcon,
                    _selectedColor,
                  ),
          child: Text(isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
