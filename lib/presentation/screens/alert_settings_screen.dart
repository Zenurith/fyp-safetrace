// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/incident_model.dart';
import '../../utils/app_theme.dart';
import '../providers/alert_settings_provider.dart';
import '../providers/category_provider.dart';

class AlertSettingsScreen extends StatefulWidget {
  final VoidCallback? onSaved;
  const AlertSettingsScreen({super.key, this.onSaved});

  @override
  State<AlertSettingsScreen> createState() => _AlertSettingsScreenState();
}

class _AlertSettingsScreenState extends State<AlertSettingsScreen> {
  bool _saved = false;
  late final AlertSettingsProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = context.read<AlertSettingsProvider>();
  }

  @override
  void dispose() {
    if (!_saved) _provider.discardChanges();
    super.dispose();
  }
  /// Converts a "10:00 PM" formatted string to a [TimeOfDay].
  TimeOfDay _parseTimeString(String timeStr) {
    try {
      final parts = timeStr.trim().split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      final int minute = int.parse(timeParts[1]);
      final String period = parts[1].toUpperCase();
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return const TimeOfDay(hour: 22, minute: 0);
    }
  }

  /// Formats a [TimeOfDay] to "10:00 PM" style string.
  String _formatTimeOfDay(TimeOfDay time) {
    final hour12 = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour12:$minute $period';
  }

  Future<void> _pickActiveFrom(
      BuildContext ctx, AlertSettingsProvider provider) async {
    final initial = _parseTimeString(provider.settings.activeFrom);
    final picked = await showTimePicker(
      context: ctx,
      initialTime: initial,
      helpText: 'Select active hours start',
    );
    if (picked != null) {
      provider.updateActiveFrom(_formatTimeOfDay(picked));
    }
  }

  Future<void> _pickActiveTo(
      BuildContext ctx, AlertSettingsProvider provider) async {
    final initial = _parseTimeString(provider.settings.activeTo);
    final picked = await showTimePicker(
      context: ctx,
      initialTime: initial,
      helpText: 'Select active hours end',
    );
    if (picked != null) {
      provider.updateActiveTo(_formatTimeOfDay(picked));
    }
  }

  Future<void> _pickQuietFrom(
      BuildContext ctx, AlertSettingsProvider provider) async {
    final initial = _parseTimeString(provider.settings.quietFrom);
    final picked = await showTimePicker(
      context: ctx,
      initialTime: initial,
      helpText: 'Select quiet hours start',
    );
    if (picked != null) {
      provider.updateQuietFrom(_formatTimeOfDay(picked));
    }
  }

  Future<void> _pickQuietTo(
      BuildContext ctx, AlertSettingsProvider provider) async {
    final initial = _parseTimeString(provider.settings.quietTo);
    final picked = await showTimePicker(
      context: ctx,
      initialTime: initial,
      helpText: 'Select quiet hours end',
    );
    if (picked != null) {
      provider.updateQuietTo(_formatTimeOfDay(picked));
    }
  }

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
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    width: 200,
                    height: 140,
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundGrey,
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
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...[2.0, 5.0, 10.0].map((r) => RadioListTile<double>(
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
                  style: TextStyle(color: AppTheme.textSecondary),
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
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: settings.activeHoursEnabled,
                      activeTrackColor: AppTheme.primaryDark,
                      onChanged: (v) => provider.toggleActiveHours(v),
                    ),
                  ],
                ),
                if (settings.activeHoursEnabled) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: AppTheme.cardDecoration,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TimePickerRow(
                          label: 'From',
                          timeStr: settings.activeFrom,
                          onTap: () => _pickActiveFrom(context, provider),
                        ),
                        const SizedBox(height: 8),
                        _TimePickerRow(
                          label: 'To',
                          timeStr: settings.activeTo,
                          onTap: () => _pickActiveTo(context, provider),
                        ),
                      ],
                    ),
                  ),
                ],
                const Divider(height: 32),
                // Quiet Hours (Do Not Disturb)
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quiet Hours (Do Not Disturb)',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Suppress alerts during selected hours',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: settings.quietHoursEnabled,
                      activeColor: AppTheme.primaryRed,
                      onChanged: (v) => provider.toggleQuietHours(v),
                    ),
                  ],
                ),
                if (settings.quietHoursEnabled) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: AppTheme.cardDecoration,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TimePickerRow(
                          label: 'From',
                          timeStr: settings.quietFrom,
                          onTap: () => _pickQuietFrom(context, provider),
                        ),
                        const SizedBox(height: 8),
                        _TimePickerRow(
                          label: 'To',
                          timeStr: settings.quietTo,
                          onTap: () => _pickQuietTo(context, provider),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _saved = true;
                      provider.saveSettings();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Settings saved')),
                      );
                      widget.onSaved?.call();
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
}

class _TimePickerRow extends StatelessWidget {
  final String label;
  final String timeStr;
  final VoidCallback onTap;

  const _TimePickerRow({
    required this.label,
    required this.timeStr,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppTheme.textSecondary,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.backgroundGrey,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Text(
                timeStr,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryDark,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
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
                color: checked ? AppTheme.primaryDark : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: checked ? AppTheme.primaryDark : AppTheme.textSecondary,
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
            color: selected ? color : AppTheme.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : AppTheme.textSecondary,
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
      case IncidentCategory.other:
        return 'Other';
    }
  }
}
