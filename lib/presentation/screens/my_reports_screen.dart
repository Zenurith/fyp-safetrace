import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/share_utils.dart';
import '../../data/models/incident_model.dart';
import '../../utils/app_theme.dart';
import '../providers/incident_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/incident_bottom_sheet.dart';

class MyReportsScreen extends StatefulWidget {
  final Function(int)? onSwitchTab;

  const MyReportsScreen({super.key, this.onSwitchTab});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  bool _reportsListening = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_reportsListening) {
      final userId = context.read<UserProvider>().currentUser?.id;
      if (userId != null) {
        context.read<IncidentProvider>().startListeningMyReports(userId);
        _reportsListening = true;
      }
    }
  }

  void _showDetail(BuildContext context, IncidentModel incident) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: IncidentBottomSheet(
            incidentId: incident.id,
            onViewOnMap: () {
              Navigator.pop(context);
              Navigator.pop(context); // pop MyReportsScreen
              context.read<IncidentProvider>().selectIncident(incident);
              widget.onSwitchTab?.call(0);
            },
          ),
        ),
      ),
    );
  }

  void _share(BuildContext context, IncidentModel incident) {
    showShareOptions(context, incident);
  }

  void _confirmDelete(BuildContext context, IncidentModel incident) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Report'),
        content: Text('Delete "${incident.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              await context.read<IncidentProvider>().deleteIncident(incident.id);
              if (context.mounted) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Report deleted'),
                    backgroundColor: AppTheme.primaryRed,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context, IncidentModel incident) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _EditIncidentSheet(
        incident: incident,
        onSave: (updated) async {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(ctx);
          await context.read<IncidentProvider>().updateIncident(updated);
          if (context.mounted) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Report updated'),
                backgroundColor: AppTheme.successGreen,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reports = context.watch<IncidentProvider>().myReports;

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: Text(
          'My Reports',
          style: AppTheme.headingMedium.copyWith(color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (reports.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${reports.length} total',
                  style: AppTheme.caption.copyWith(color: Colors.white70),
                ),
              ),
            ),
        ],
      ),
      body: reports.isEmpty ? _buildEmptyState() : _buildList(reports),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.report_outlined, size: 64, color: AppTheme.cardBorder),
          const SizedBox(height: 16),
          Text(
            'No reports yet',
            style: AppTheme.headingSmall.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Your submitted incident reports\nwill appear here',
            textAlign: TextAlign.center,
            style: AppTheme.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<IncidentModel> reports) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: reports.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final incident = reports[index];
        return _ReportCard(
          incident: incident,
          onTap: () => _showDetail(context, incident),
          onEdit: () => _showEditSheet(context, incident),
          onDelete: () => _confirmDelete(context, incident),
          onShare: () => _share(context, incident),
        );
      },
    );
  }
}

// ── Cards ─────────────────────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  final IncidentModel incident;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onShare;

  const _ReportCard({
    required this.incident,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onShare,
  });

  Color get _statusColor {
    switch (incident.status) {
      case IncidentStatus.pending:
        return AppTheme.warningOrange;
      case IncidentStatus.underReview:
        return AppTheme.primaryDark;
      case IncidentStatus.verified:
        return AppTheme.successGreen;
      case IncidentStatus.resolved:
        return AppTheme.successGreen;
      case IncidentStatus.dismissed:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = AppTheme.categoryColor(incident.categoryLabel);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: AppTheme.cardDecoration,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Category color bar
            Container(
              width: 4,
              height: 72,
              decoration: BoxDecoration(
                color: categoryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident.title,
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _Chip(label: incident.categoryLabel, color: categoryColor),
                        const SizedBox(width: 6),
                        _Chip(label: incident.statusLabel, color: _statusColor),
                        const SizedBox(width: 6),
                        Text(incident.timeAgo, style: AppTheme.caption),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Actions menu
            PopupMenuButton<_CardAction>(
              icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary, size: 20),
              onSelected: (action) {
                switch (action) {
                  case _CardAction.edit:
                    onEdit();
                    break;
                  case _CardAction.share:
                    onShare();
                    break;
                  case _CardAction.delete:
                    onDelete();
                    break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: _CardAction.edit,
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: _CardAction.share,
                  child: Row(
                    children: [
                      Icon(Icons.share_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Share'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _CardAction.delete,
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: AppTheme.primaryRed),
                      const SizedBox(width: 10),
                      Text('Delete', style: TextStyle(color: AppTheme.primaryRed)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _CardAction { edit, share, delete }

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ── Edit Sheet ────────────────────────────────────────────────────────────────

class _EditIncidentSheet extends StatefulWidget {
  final IncidentModel incident;
  final Future<void> Function(IncidentModel) onSave;

  const _EditIncidentSheet({required this.incident, required this.onSave});

  @override
  State<_EditIncidentSheet> createState() => _EditIncidentSheetState();
}

class _EditIncidentSheetState extends State<_EditIncidentSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late IncidentCategory _category;
  late SeverityLevel _severity;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.incident.title);
    _descController = TextEditingController(text: widget.incident.description);
    _category = widget.incident.category;
    _severity = widget.incident.severity;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final updated = widget.incident.copyWith(
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      category: _category,
      severity: _severity,
    );
    await widget.onSave(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Edit Report', style: AppTheme.headingSmall),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            maxLength: 100,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            maxLines: 3,
            maxLength: 500,
          ),
          const SizedBox(height: 12),
          Text('Category', style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: IncidentCategory.values.map((cat) {
              final label = cat.name[0].toUpperCase() + cat.name.substring(1);
              final isSelected = _category == cat;
              return GestureDetector(
                onTap: () => setState(() => _category = cat),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryDark : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryDark : AppTheme.cardBorder,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      color: isSelected ? Colors.white : AppTheme.primaryDark,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text('Severity', style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: SeverityLevel.values.map((sev) {
              final label = sev.name[0].toUpperCase() + sev.name.substring(1);
              final isSelected = _severity == sev;
              final color = sev == SeverityLevel.high
                  ? AppTheme.primaryRed
                  : sev == SeverityLevel.moderate
                      ? AppTheme.warningOrange
                      : AppTheme.successGreen;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _severity = sev),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? color : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? color : AppTheme.cardBorder),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        color: isSelected ? Colors.white : AppTheme.primaryDark,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }
}
