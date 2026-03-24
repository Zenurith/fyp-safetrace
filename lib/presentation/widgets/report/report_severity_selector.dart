import 'package:flutter/material.dart';
import '../../../data/models/incident_model.dart';
import '../../../utils/app_theme.dart';
import '../../../utils/incident_enum_helpers.dart';

class ReportSeveritySelector extends StatelessWidget {
  final SeverityLevel selectedSeverity;
  final ValueChanged<SeverityLevel> onSeverityChanged;

  const ReportSeveritySelector({
    super.key,
    required this.selectedSeverity,
    required this.onSeverityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: SeverityLevel.values.map((level) {
        final selected = selectedSeverity == level;
        final color = severityColor(level);
        return GestureDetector(
          onTap: () => onSeverityChanged(level),
          child: Column(
            children: [
              Container(
                width: selected ? 56 : 44,
                height: selected ? 56 : 44,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: selected
                      ? Border.all(color: Colors.white, width: 3)
                      : null,
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          )
                        ]
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                severityLabel(level),
                style: TextStyle(
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? AppTheme.primaryDark : Colors.grey,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
