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
  String? _selectedFormat;

  Future<void> _export(String format) async {
    setState(() {
      _isExporting = true;
      _selectedFormat = format;
    });

    final incidents = context.read<IncidentProvider>().allIncidents;

    String? filePath;
    if (format == 'csv') {
      filePath = await ExportService.exportToCsv(incidents);
    } else {
      filePath = await ExportService.exportToPdf(incidents);
    }

    if (!mounted) return;

    setState(() => _isExporting = false);

    if (filePath != null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported ${incidents.length} incidents to ${format.toUpperCase()}'),
          backgroundColor: AppTheme.successGreen,
          action: SnackBarAction(
            label: 'Share',
            textColor: Colors.white,
            onPressed: () => ExportService.shareFile(filePath!),
          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final incidents = context.watch<IncidentProvider>().allIncidents;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.download, color: AppTheme.primaryDark),
          const SizedBox(width: 8),
          const Text('Export Reports'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${incidents.length} incidents will be exported',
            style: TextStyle(
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Select format:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 12),
          _ExportOption(
            icon: Icons.table_chart,
            title: 'CSV',
            subtitle: 'Spreadsheet format',
            isLoading: _isExporting && _selectedFormat == 'csv',
            onTap: _isExporting ? null : () => _export('csv'),
          ),
          const SizedBox(height: 8),
          _ExportOption(
            icon: Icons.picture_as_pdf,
            title: 'PDF',
            subtitle: 'Document format',
            isLoading: _isExporting && _selectedFormat == 'pdf',
            onTap: _isExporting ? null : () => _export('pdf'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isExporting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _ExportOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLoading;
  final VoidCallback? onTap;

  const _ExportOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppTheme.primaryRed, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.primaryDark,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                Icons.chevron_right,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}
