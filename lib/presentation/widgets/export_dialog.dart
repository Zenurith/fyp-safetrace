import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/services/export_service.dart';
import '../../utils/app_theme.dart';
import '../providers/incident_provider.dart';

class ExportDialog extends StatefulWidget {
  const ExportDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const ExportDialog(),
    );
  }

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  bool _isExporting = false;

  Future<void> _export() async {
    setState(() => _isExporting = true);

    final incidents = context.read<IncidentProvider>().allIncidents;
    final filePath = await ExportService.exportToPdf(incidents);

    if (!mounted) return;
    setState(() => _isExporting = false);

    if (filePath != null || kIsWeb) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? 'Downloaded ${incidents.length} incidents as PDF'
                : 'Exported ${incidents.length} incidents to PDF',
          ),
          backgroundColor: AppTheme.successGreen,
          action: (!kIsWeb && filePath != null)
              ? SnackBarAction(
                  label: 'Share',
                  textColor: Colors.white,
                  onPressed: () => ExportService.shareFile(filePath),
                )
              : null,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to export. Please try again.'),
          backgroundColor: AppTheme.primaryRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final incidents = context.watch<IncidentProvider>().allIncidents;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.picture_as_pdf, color: AppTheme.primaryDark),
          SizedBox(width: 8),
          Text('Export Reports'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${incidents.length} incidents will be exported as PDF.',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isExporting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isExporting ? null : _export,
          icon: _isExporting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.download, size: 16),
          label: const Text('Export PDF'),
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryDark),
        ),
      ],
    );
  }
}

