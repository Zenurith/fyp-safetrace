import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/models/incident_model.dart';
import '../../data/services/export_service.dart';
import '../../utils/app_theme.dart';
import '../providers/incident_provider.dart';

enum _ExportFormat { pdf, csv }

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
  _ExportFormat _format = _ExportFormat.pdf;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  final Set<IncidentStatus> _statusFilter = {};

  static final _dateFormat = DateFormat('MMM d, y');

  List<IncidentModel> _applyFilters(List<IncidentModel> all) {
    var list = all;
    if (_dateFrom != null) {
      list = list.where((i) => !i.reportedAt.isBefore(_dateFrom!)).toList();
    }
    if (_dateTo != null) {
      final endOfDay = DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day, 23, 59, 59);
      list = list.where((i) => !i.reportedAt.isAfter(endOfDay)).toList();
    }
    if (_statusFilter.isNotEmpty) {
      list = list.where((i) => _statusFilter.contains(i.status)).toList();
    }
    return list;
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? (_dateFrom ?? DateTime.now()) : (_dateTo ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _dateFrom = picked;
        if (_dateTo != null && _dateTo!.isBefore(_dateFrom!)) _dateTo = null;
      } else {
        _dateTo = picked;
        if (_dateFrom != null && _dateFrom!.isAfter(_dateTo!)) _dateFrom = null;
      }
    });
  }

  Future<void> _export() async {
    setState(() => _isExporting = true);

    final all = context.read<IncidentProvider>().allIncidents;
    final filtered = _applyFilters(all);

    if (filtered.isEmpty) {
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No incidents match the selected filters.'),
          backgroundColor: AppTheme.warningOrange,
        ),
      );
      return;
    }

    String? filePath;
    if (_format == _ExportFormat.pdf) {
      filePath = await ExportService.exportToPdf(filtered);
    } else {
      filePath = await ExportService.exportToCsv(filtered);
    }

    if (!mounted) return;
    setState(() => _isExporting = false);

    final formatLabel = _format == _ExportFormat.pdf ? 'PDF' : 'CSV';

    if (filePath != null || kIsWeb) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? 'Downloaded ${filtered.length} incidents as $formatLabel'
                : 'Exported ${filtered.length} incidents to $formatLabel',
          ),
          backgroundColor: AppTheme.successGreen,
          action: (!kIsWeb && filePath != null)
              ? SnackBarAction(
                  label: 'Share',
                  textColor: Colors.white,
                  onPressed: () => ExportService.shareFile(filePath!),
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
    final allIncidents = context.watch<IncidentProvider>().allIncidents;
    final filtered = _applyFilters(allIncidents);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.download_rounded, color: AppTheme.primaryDark),
          SizedBox(width: 8),
          Text('Export Reports'),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Format selector
            _sectionLabel('Format'),
            const SizedBox(height: 8),
            SegmentedButton<_ExportFormat>(
              segments: const [
                ButtonSegment(
                  value: _ExportFormat.pdf,
                  icon: Icon(Icons.picture_as_pdf, size: 16),
                  label: Text('PDF'),
                ),
                ButtonSegment(
                  value: _ExportFormat.csv,
                  icon: Icon(Icons.table_chart, size: 16),
                  label: Text('CSV'),
                ),
              ],
              selected: {_format},
              onSelectionChanged: (s) => setState(() => _format = s.first),
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
            const SizedBox(height: 16),

            // Date range
            _sectionLabel('Date Range (reported at)'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _dateButton('From', _dateFrom, () => _pickDate(isFrom: true)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _dateButton('To', _dateTo, () => _pickDate(isFrom: false)),
                ),
                if (_dateFrom != null || _dateTo != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    tooltip: 'Clear dates',
                    onPressed: () => setState(() {
                      _dateFrom = null;
                      _dateTo = null;
                    }),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Status filter
            _sectionLabel('Status  (none selected = all)'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: IncidentStatus.values.map((status) {
                final selected = _statusFilter.contains(status);
                return FilterChip(
                  label: Text(status.label, style: const TextStyle(fontSize: 12)),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _statusFilter.add(status);
                    } else {
                      _statusFilter.remove(status);
                    }
                  }),
                  visualDensity: VisualDensity.compact,
                  selectedColor: AppTheme.primaryDark.withValues(alpha: 0.12),
                  checkmarkColor: AppTheme.primaryDark,
                  side: BorderSide(
                    color: selected ? AppTheme.primaryDark : AppTheme.cardBorder,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Live preview count
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.backgroundGrey,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    '${filtered.length} of ${allIncidents.length} incidents will be exported',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
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
          label: Text(_format == _ExportFormat.pdf ? 'Export PDF' : 'Export CSV'),
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryDark),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _dateButton(String placeholder, DateTime? date, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        side: const BorderSide(color: AppTheme.cardBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        foregroundColor: AppTheme.primaryDark,
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today,
            size: 13,
            color: date != null ? AppTheme.primaryDark : AppTheme.textSecondary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              date != null ? _dateFormat.format(date) : placeholder,
              style: TextStyle(
                fontSize: 12,
                color: date != null ? AppTheme.primaryDark : AppTheme.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

extension _StatusLabel on IncidentStatus {
  String get label {
    switch (this) {
      case IncidentStatus.pending:
        return 'Pending';
      case IncidentStatus.underReview:
        return 'Under Review';
      case IncidentStatus.verified:
        return 'Verified';
      case IncidentStatus.resolved:
        return 'Resolved';
      case IncidentStatus.dismissed:
        return 'Dismissed';
    }
  }
}
