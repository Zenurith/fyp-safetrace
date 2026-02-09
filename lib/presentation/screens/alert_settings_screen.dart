// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/incident_model.dart';
import '../../data/models/category_model.dart';
import '../../utils/app_theme.dart';
import '../providers/alert_settings_provider.dart';
import '../providers/category_provider.dart';

class AlertSettingsScreen extends StatelessWidget {
  const AlertSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alert Settings'),
      ),
      body: Consumer<AlertSettingsProvider>(
        builder: (context, provider, _) {
          final settings = provider.settings;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Alert Radius
                const Text(
                  'Alert Radius',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Receive alerts for incidents within:',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    width: 200,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Dashed circle representation
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.primaryRed.withValues(alpha: 0.4),
                                width: 2,
                                strokeAlign: BorderSide.strokeAlignOutside,
                              ),
                            ),
                          ),
                          Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Positioned(
                            bottom: 10,
                            child: Text(
                              '${settings.radiusKm.toInt()} km radius',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...[1.0, 2.0, 5.0].map((r) => RadioListTile<double>(
                      title: Text('${r.toInt()} km'),
                      value: r,
                      groupValue: settings.radiusKm,
                      activeColor: AppTheme.primaryRed,
                      onChanged: (v) {
                        if (v != null) provider.updateRadius(v);
                      },
                    )),
                const Divider(height: 32),
                // Severity Filter
                const Text(
                  'Severity Filter',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Notify me about:',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                _SeverityCheckbox(
                  label: 'High severity incidents',
                  color: AppTheme.severityHigh,
                  checked: settings.severityFilters.contains(SeverityLevel.high),
                  onChanged: () => provider.toggleSeverity(SeverityLevel.high),
                ),
                _SeverityCheckbox(
                  label: 'Moderate severity incidents',
                  color: AppTheme.severityModerate,
                  checked: settings.severityFilters.contains(SeverityLevel.moderate),
                  onChanged: () => provider.toggleSeverity(SeverityLevel.moderate),
                ),
                _SeverityCheckbox(
                  label: 'Low severity incidents',
                  color: AppTheme.severityLow,
                  checked: settings.severityFilters.contains(SeverityLevel.low),
                  onChanged: () => provider.toggleSeverity(SeverityLevel.low),
                ),
                const Divider(height: 32),
                // Category Preferences
                const Text(
                  'Category Preferences',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Alert categories:',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                _CategoryFilterGrid(
                  selectedCategories: settings.categoryFilters,
                  onToggle: provider.toggleCategory,
                ),
                const SizedBox(height: 24),
                // Active Hours
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Active Hours',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Custom notification hours',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: settings.activeHoursEnabled,
                      activeColor: AppTheme.accentBlue,
                      onChanged: (v) => provider.toggleActiveHours(v),
                    ),
                  ],
                ),
                if (settings.activeHoursEnabled) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'From ${settings.activeFrom} to ${settings.activeTo}',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      provider.saveSettings();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Settings saved')),
                      );
                    },
                    child: const Text(
                      'Save Settings',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  String _categoryLabel(IncidentCategory cat) {
    switch (cat) {
      case IncidentCategory.crime:
        return 'Crime';
      case IncidentCategory.infrastructure:
        return 'Infrastructure';
      case IncidentCategory.suspicious:
        return 'Suspicious';
      case IncidentCategory.traffic:
        return 'Traffic';
      case IncidentCategory.environmental:
        return 'Environmental';
      case IncidentCategory.emergency:
        return 'Emergency';
    }
  }
}

class _SeverityCheckbox extends StatelessWidget {
  final String label;
  final Color color;
  final bool checked;
  final VoidCallback onChanged;

  const _SeverityCheckbox({
    required this.label,
    required this.color,
    required this.checked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: checked ? AppTheme.accentBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: checked ? AppTheme.accentBlue : Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child: checked
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

class _CategoryFilterGrid extends StatelessWidget {
  final Set<IncidentCategory> selectedCategories;
  final Function(IncidentCategory) onToggle;

  const _CategoryFilterGrid({
    required this.selectedCategories,
    required this.onToggle,
  });

  IncidentCategory? _getIncidentCategoryFromName(String name) {
    switch (name.toLowerCase()) {
      case 'crime':
        return IncidentCategory.crime;
      case 'infrastructure':
        return IncidentCategory.infrastructure;
      case 'suspicious':
        return IncidentCategory.suspicious;
      case 'traffic':
        return IncidentCategory.traffic;
      case 'environmental':
        return IncidentCategory.environmental;
      case 'emergency':
        return IncidentCategory.emergency;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final enabledCategories = categoryProvider.enabledCategories;

    // Filter to only show categories that have a matching IncidentCategory enum
    final availableCategories = enabledCategories.where((cat) {
      return _getIncidentCategoryFromName(cat.name) != null;
    }).toList();

    // If no enabled categories from provider, fall back to all enum values
    if (availableCategories.isEmpty) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: IncidentCategory.values.map((cat) {
          final label = _categoryLabel(cat);
          final selected = selectedCategories.contains(cat);
          return _buildCategoryChip(
            label: label,
            color: AppTheme.categoryColor(label),
            selected: selected,
            onTap: () => onToggle(cat),
          );
        }).toList(),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: availableCategories.map((cat) {
        final incidentCat = _getIncidentCategoryFromName(cat.name);
        if (incidentCat == null) return const SizedBox.shrink();

        final selected = selectedCategories.contains(incidentCat);
        return _buildCategoryChip(
          label: cat.name,
          color: cat.color,
          selected: selected,
          onTap: () => onToggle(incidentCat),
        );
      }).toList(),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : Colors.grey[600],
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  String _categoryLabel(IncidentCategory cat) {
    switch (cat) {
      case IncidentCategory.crime:
        return 'Crime';
      case IncidentCategory.infrastructure:
        return 'Infrastructure';
      case IncidentCategory.suspicious:
        return 'Suspicious';
      case IncidentCategory.traffic:
        return 'Traffic';
      case IncidentCategory.environmental:
        return 'Environmental';
      case IncidentCategory.emergency:
        return 'Emergency';
    }
  }
}
