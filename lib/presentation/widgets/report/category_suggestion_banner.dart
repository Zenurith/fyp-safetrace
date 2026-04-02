import 'package:flutter/material.dart';
import '../../../data/models/incident_model.dart';
import '../../../utils/app_theme.dart';
import '../../../utils/incident_enum_helpers.dart';

class CategorySuggestionBanner extends StatelessWidget {
  final IncidentCategory? suggestedCategory;
  final IncidentCategory selectedCategory;
  final bool isLoading;
  final ValueChanged<IncidentCategory> onApply;
  final VoidCallback onDismiss;

  const CategorySuggestionBanner({
    super.key,
    required this.suggestedCategory,
    required this.selectedCategory,
    this.isLoading = false,
    required this.onApply,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.backgroundGrey,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              'Suggesting category…',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ],
        ),
      );
    }

    final suggested = suggestedCategory;
    if (suggested == null) return const SizedBox.shrink();

    final isMatch = suggested == selectedCategory;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMatch
            ? AppTheme.successGreen.withValues(alpha: 0.1)
            : AppTheme.warningOrange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isMatch
              ? AppTheme.successGreen.withValues(alpha: 0.4)
              : AppTheme.warningOrange.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isMatch ? Icons.check_circle_outline : Icons.lightbulb_outline,
            color: isMatch ? AppTheme.successGreen : AppTheme.warningOrange,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isMatch
                  ? 'Category looks correct: ${categoryLabel(suggested)}'
                  : 'Suggested: ${categoryLabel(suggested)}',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.primaryDark,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ),
          if (!isMatch)
            TextButton(
              onPressed: () => onApply(suggested),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.warningOrange,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Apply',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            color: AppTheme.textSecondary,
            onPressed: onDismiss,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
