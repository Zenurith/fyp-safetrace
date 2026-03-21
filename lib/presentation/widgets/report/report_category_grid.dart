import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/incident_model.dart';
import '../../../utils/app_theme.dart';
import '../../../utils/incident_enum_helpers.dart';
import '../../providers/category_provider.dart';

class ReportCategoryGrid extends StatelessWidget {
  final IncidentCategory selectedCategory;
  final ValueChanged<IncidentCategory> onCategorySelected;

  const ReportCategoryGrid({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final enabledCategories = categoryProvider.enabledCategories;

    final availableCategories = enabledCategories
        .where((cat) => incidentCategoryFromName(cat.name) != null)
        .toList();

    if (availableCategories.isEmpty) {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.1,
        children: IncidentCategory.values.map((cat) {
          return _CategoryItem(
            label: categoryLabel(cat),
            icon: categoryIcon(cat),
            color: AppTheme.categoryColor(categoryLabel(cat)),
            selected: selectedCategory == cat,
            onTap: () => onCategorySelected(cat),
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
      children: availableCategories.map((cat) {
        final incidentCat = incidentCategoryFromName(cat.name);
        if (incidentCat == null) return const SizedBox.shrink();

        return _CategoryItem(
          label: cat.name,
          icon: cat.icon,
          color: cat.color,
          selected: selectedCategory == incidentCat,
          onTap: () => onCategorySelected(incidentCat),
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
          borderRadius: BorderRadius.circular(12),
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
