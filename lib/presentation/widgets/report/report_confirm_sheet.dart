import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/models/incident_model.dart';
import '../../../utils/app_theme.dart';
import '../../../utils/incident_enum_helpers.dart';

/// Shows a bottom sheet summary. Returns true if the user tapped Submit,
/// false if they tapped Edit or dismissed.
Future<bool> showReportConfirmSheet({
  required BuildContext context,
  required String title,
  required IncidentCategory category,
  required SeverityLevel severity,
  required String address,
  required DateTime? incidentTime,
  required int mediaCount,
  required bool isAnonymous,
  String? communityName,
}) async {
  bool confirmed = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Confirm Report',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: AppTheme.fontFamily,
                  color: AppTheme.primaryDark,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: AppTheme.fontFamily,
                  color: AppTheme.primaryDark,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(
                      categoryLabel(category),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                    backgroundColor:
                        AppTheme.categoryColor(categoryLabel(category)),
                    padding: EdgeInsets.zero,
                  ),
                  Chip(
                    label: Text(
                      severityLabel(severity),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                    backgroundColor: severityColor(severity),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(address, style: AppTheme.caption),
                  ),
                ],
              ),
              if (incidentTime != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.schedule,
                        size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'When: ${DateFormat('dd MMM yyyy, h:mm a').format(incidentTime)}',
                      style: AppTheme.caption,
                    ),
                  ],
                ),
              ],
              if (mediaCount > 0) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.photo_library_outlined,
                        size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '$mediaCount media file(s) attached',
                      style: AppTheme.caption,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    isAnonymous
                        ? Icons.visibility_off_outlined
                        : Icons.person_outline,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isAnonymous
                        ? 'Submitted anonymously'
                        : 'Submitted with your name',
                    style: AppTheme.caption,
                  ),
                ],
              ),
              if (communityName != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.group_outlined,
                        size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text('Shared to: $communityName', style: AppTheme.caption),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        confirmed = true;
                        Navigator.pop(sheetContext);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryRed,
                      ),
                      child: const Text('Submit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  return confirmed;
}
