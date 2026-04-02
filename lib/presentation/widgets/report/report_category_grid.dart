import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/incident_model.dart';
import '../../../utils/app_theme.dart';
import '../../../utils/incident_enum_helpers.dart';
import '../../providers/category_provider.dart';

class ReportCategoryGrid extends StatelessWidget {
  final IncidentCategory selectedCategory;
  final String? selectedCategoryName; // Non-null only for custom categories
  final void Function(IncidentCategory category, String? customName) onCategorySelected;

  const ReportCategoryGrid({
    super.key,
    required this.selectedCategory,
    this.selectedCategoryName,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final enabledCategories = categoryProvider.enabledCategories;

    if (enabledCategories.isEmpty) {
      // Fallback to hardcoded enum list while admin categories load
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.1,
        children: IncidentCategory.values
            .where((c) => c != IncidentCategory.other)
            .map((cat) {
          return _CategoryItem(
            label: categoryLabel(cat),
            icon: categoryIcon(cat),
            color: AppTheme.categoryColor(categoryLabel(cat)),
            selected: selectedCategory == cat,
            onTap: () => onCategorySelected(cat, null),
          );
        }).toList(),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.1,
      children: enabledCategories.map((cat) {
        final incidentCat = incidentCategoryFromName(cat.name);
        final isCustom = incidentCat == IncidentCategory.other;
        final selected = isCustom
            ? selectedCategoryName == cat.name
            : selectedCategory == incidentCat;

        return _CategoryItem(
          label: cat.name,
          icon: cat.icon,
          color: cat.color,
          selected: selected,
          onTap: () => onCategorySelected(incidentCat, isCustom ? cat.name : null),
        );
      }).toList(),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppTheme.primaryRed : Colors.grey[300]!,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: selected ? color : Colors.grey[600],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? AppTheme.primaryDark : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
