import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../utils/app_theme.dart';

class IncidentTimePickerTile extends StatelessWidget {
  final DateTime? incidentTime;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const IncidentTimePickerTile({
    super.key,
    required this.incidentTime,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.cardBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule,
                color: AppTheme.primaryRed, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    incidentTime == null
                        ? 'Just now'
                        : DateFormat('dd MMM yyyy, h:mm a')
                            .format(incidentTime!),
                    style: TextStyle(
                      fontSize: 15,
                      color: incidentTime == null
                          ? AppTheme.textSecondary
                          : AppTheme.primaryDark,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                  if (incidentTime != null)
                    Text('Tap to change', style: AppTheme.caption),
                ],
              ),
            ),
            if (incidentTime != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: AppTheme.textSecondary,
                onPressed: onClear,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }
}
