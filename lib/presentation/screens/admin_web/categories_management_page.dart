import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/category_model.dart';
import '../../../utils/app_theme.dart';
import '../../providers/category_provider.dart';
import '../../widgets/admin_web/responsive_layout.dart';

class CategoriesManagementPage extends StatelessWidget {
  const CategoriesManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final categories = categoryProvider.categories;
    final columns = ResponsiveLayout.getGridColumns(context);

    if (categoryProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (categoryProvider.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Error loading categories',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => categoryProvider.initialize(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        categories.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.category_outlined,
                      size: 64,
                      color: AppTheme.textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No categories found',
                      style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showAddCategoryDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Category'),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats row
                    Row(
                      children: [
                        _StatCard(
                          label: 'Total',
                          value: '${categories.length}',
                          icon: Icons.category_outlined,
                          color: AppTheme.primaryDark,
                        ),
                        const SizedBox(width: 16),
                        _StatCard(
                          label: 'Enabled',
                          value: '${categories.where((c) => c.isEnabled).length}',
                          icon: Icons.check_circle_outline,
                          color: AppTheme.successGreen,
                        ),
                        const SizedBox(width: 16),
                        _StatCard(
                          label: 'Disabled',
                          value: '${categories.where((c) => !c.isEnabled).length}',
                          icon: Icons.cancel_outlined,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 16),
                        _StatCard(
                          label: 'Custom',
                          value: '${categories.where((c) => !c.isDefault).length}',
                          icon: Icons.edit_outlined,
                          color: AppTheme.primaryDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Categories grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 2.5,
                      ),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        return _CategoryCard(category: categories[index]);
                      },
                    ),
                  ],
                ),
              ),

        // FAB
        Positioned(
          right: 24,
          bottom: 24,
          child: FloatingActionButton.extended(
            onPressed: () => _showAddCategoryDialog(context),
            backgroundColor: AppTheme.primaryRed,
            elevation: 2,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Add Category',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Category "$name" added'),
                backgroundColor: AppTheme.successGreen,
              ),
            );
          }
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecorationFor(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: AppTheme.headingMedium.copyWith(
                  color: AppTheme.primaryDark,
                ),
              ),
              Text(
                label,
                style: AppTheme.caption.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
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
      decoration: AppTheme.cardDecorationFor(context),
      child: Row(
        children: [
          // Icon preview
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: category.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(category.icon, color: category.color, size: 24),
          ),
          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        category.name,
                        style: AppTheme.headingSmall.copyWith(
                          color: AppTheme.primaryDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (category.isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                const SizedBox(height: 4),
                Text(
                  category.isEnabled ? 'Enabled' : 'Disabled',
                  style: AppTheme.caption.copyWith(
                    color: category.isEnabled ? AppTheme.successGreen : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Toggle
          Switch.adaptive(
            value: category.isEnabled,
            activeTrackColor: AppTheme.successGreen,
            onChanged: (value) {
              context.read<CategoryProvider>().toggleCategoryEnabled(category.id);
            },
          ),

          // Actions (only for non-default)
          if (!category.isDefault) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _showEditDialog(context),
              icon: Icon(
                Icons.edit_outlined,
                size: 20,
                color: AppTheme.textSecondary,
              ),
              tooltip: 'Edit',
            ),
            IconButton(
              onPressed: () => _showDeleteDialog(context),
              icon: const Icon(
                Icons.delete_outline,
                size: 20,
                color: AppTheme.primaryRed,
              ),
              tooltip: 'Delete',
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
          final result = await context.read<CategoryProvider>().updateCategory(updated);
          if (result && context.mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Category "$name" updated'),
                backgroundColor: AppTheme.successGreen,
              ),
            );
          }
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Delete Category', style: AppTheme.headingMedium),
        content: Text(
          'Are you sure you want to delete "${category.name}"?',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              final result = await context.read<CategoryProvider>().deleteCategory(category.id);
              if (result && context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Category "${category.name}" deleted'),
                    backgroundColor: AppTheme.successGreen,
                  ),
                );
              }
            },
            child: Text('Delete', style: AppTheme.bodyMedium.copyWith(color: AppTheme.primaryRed)),
          ),
        ],
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
    _nameController = TextEditingController(text: widget.category?.name ?? '');
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        isEditing ? 'Edit Category' : 'Add Category',
        style: AppTheme.headingMedium,
      ),
      content: SizedBox(
        width: 400,
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
              const SizedBox(height: 20),
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
                          color: isSelected ? _getColor(_selectedColor) : AppTheme.cardBorder,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Icon(
                        _getIconData(iconName),
                        color: isSelected ? _getColor(_selectedColor) : AppTheme.textSecondary,
                        size: 22,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
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
                          color: isSelected ? AppTheme.primaryDark : Colors.transparent,
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
              const SizedBox(height: 20),
              // Preview
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
                      _nameController.text.isEmpty ? 'Preview' : _nameController.text,
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
          child: Text('Cancel', style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _nameController.text.trim().isEmpty
              ? null
              : () {
                  widget.onSave(
                    _nameController.text.trim(),
                    _selectedIcon,
                    _selectedColor,
                  );
                },
          child: Text(isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
