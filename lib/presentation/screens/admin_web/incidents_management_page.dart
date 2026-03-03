import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/incident_model.dart';
import '../../../utils/app_theme.dart';
import '../../providers/incident_provider.dart';
import '../../providers/category_provider.dart';

class IncidentsManagementPage extends StatefulWidget {
  const IncidentsManagementPage({super.key});

  @override
  State<IncidentsManagementPage> createState() => _IncidentsManagementPageState();
}

class _IncidentsManagementPageState extends State<IncidentsManagementPage> {
  String _searchQuery = '';
  IncidentStatus? _statusFilter;
  String? _categoryFilter;
  SeverityLevel? _severityFilter;

  List<IncidentModel> _filterIncidents(List<IncidentModel> incidents) {
    return incidents.where((incident) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!incident.title.toLowerCase().contains(query) &&
            !incident.address.toLowerCase().contains(query)) {
          return false;
        }
      }

      // Status filter
      if (_statusFilter != null && incident.status != _statusFilter) {
        return false;
      }

      // Category filter
      if (_categoryFilter != null && incident.categoryLabel != _categoryFilter) {
        return false;
      }

      // Severity filter
      if (_severityFilter != null && incident.severity != _severityFilter) {
        return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final incidentProvider = context.watch<IncidentProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final allIncidents = incidentProvider.allIncidents;
    final incidents = _filterIncidents(allIncidents);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final categoryNames = categoryProvider.categories.map((c) => c.name).toList();

    return Column(
      children: [
        // Filters bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
              ),
            ),
          ),
          child: Row(
            children: [
              // Search
              Expanded(
                flex: 2,
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: AppTheme.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Search by title or location...',
                    hintStyle: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Status filter
              _buildDropdown<IncidentStatus?>(
                value: _statusFilter,
                hint: 'All Status',
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Status')),
                  ...IncidentStatus.values.map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(_getStatusLabel(s)),
                      )),
                ],
                onChanged: (value) => setState(() => _statusFilter = value),
              ),
              const SizedBox(width: 12),

              // Category filter
              _buildDropdown<String?>(
                value: _categoryFilter,
                hint: 'All Categories',
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Categories')),
                  ...categoryNames.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                ],
                onChanged: (value) => setState(() => _categoryFilter = value),
              ),
              const SizedBox(width: 12),

              // Severity filter
              _buildDropdown<SeverityLevel?>(
                value: _severityFilter,
                hint: 'All Severity',
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Severity')),
                  ...SeverityLevel.values.map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(_getSeverityLabel(s)),
                      )),
                ],
                onChanged: (value) => setState(() => _severityFilter = value),
              ),
              const SizedBox(width: 12),

              // Clear filters
              if (_statusFilter != null ||
                  _categoryFilter != null ||
                  _severityFilter != null ||
                  _searchQuery.isNotEmpty)
                TextButton.icon(
                  onPressed: () => setState(() {
                    _searchQuery = '';
                    _statusFilter = null;
                    _categoryFilter = null;
                    _severityFilter = null;
                  }),
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('Clear'),
                ),
            ],
          ),
        ),

        // Results count
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          alignment: Alignment.centerLeft,
          child: Text(
            '${incidents.length} incidents',
            style: AppTheme.caption,
          ),
        ),

        // Incidents list
        Expanded(
          child: incidents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_outlined,
                        size: 64,
                        color: AppTheme.textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No incidents match your filters',
                        style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: incidents.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final incident = incidents[index];
                    return _IncidentCard(incident: incident);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint, style: AppTheme.bodyMedium),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  String _getStatusLabel(IncidentStatus status) {
    switch (status) {
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

  String _getSeverityLabel(SeverityLevel severity) {
    switch (severity) {
      case SeverityLevel.low:
        return 'Low';
      case SeverityLevel.moderate:
        return 'Moderate';
      case SeverityLevel.high:
        return 'High';
    }
  }
}

class _IncidentCard extends StatelessWidget {
  final IncidentModel incident;

  const _IncidentCard({required this.incident});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecorationFor(context),
      child: Row(
        children: [
          // Category icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.categoryColor(incident.categoryLabel).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: AppTheme.categoryColor(incident.categoryLabel),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),

          // Incident info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  incident.title,
                  style: AppTheme.headingSmall.copyWith(
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.primaryDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        incident.address,
                        style: AppTheme.caption.copyWith(
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Category badge
          _Badge(
            label: incident.categoryLabel,
            color: AppTheme.categoryColor(incident.categoryLabel),
          ),
          const SizedBox(width: 12),

          // Severity badge
          _Badge(
            label: incident.severityLabel,
            color: AppTheme.severityColor(incident.severityLabel),
          ),
          const SizedBox(width: 12),

          // Votes
          Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.thumb_up_outlined, size: 14, color: AppTheme.successGreen),
                  const SizedBox(width: 4),
                  Text(
                    '${incident.upvotes}',
                    style: AppTheme.caption.copyWith(color: AppTheme.successGreen),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.thumb_down_outlined, size: 14, color: AppTheme.primaryRed),
                  const SizedBox(width: 4),
                  Text(
                    '${incident.downvotes}',
                    style: AppTheme.caption.copyWith(color: AppTheme.primaryRed),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 16),

          // Status chip
          _StatusChip(status: incident.status),
          const SizedBox(width: 16),

          // Actions
          _ActionButton(
            icon: Icons.edit_outlined,
            onTap: () => _showStatusDialog(context),
          ),
          const SizedBox(width: 8),
          _ActionButton(
            icon: Icons.delete_outline,
            color: AppTheme.primaryRed,
            onTap: () => _showDeleteDialog(context),
          ),
        ],
      ),
    );
  }

  void _showStatusDialog(BuildContext context) {
    final noteController = TextEditingController();
    IncidentStatus selectedStatus = incident.status;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Update Status', style: AppTheme.headingMedium),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(incident.title, style: AppTheme.headingSmall),
                const SizedBox(height: 4),
                Text(incident.address, style: AppTheme.caption),
                const SizedBox(height: 16),
                ...IncidentStatus.values.map((status) {
                  final isSelected = selectedStatus == status;
                  return GestureDetector(
                    onTap: () => setState(() => selectedStatus = status),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _getStatusColor(status).withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? _getStatusColor(status) : AppTheme.cardBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? _getStatusColor(status) : AppTheme.cardBorder,
                                width: 2,
                              ),
                              color: isSelected ? _getStatusColor(status) : Colors.transparent,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, size: 14, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getStatusLabel(status),
                                  style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  _getStatusDescription(status),
                                  style: AppTheme.caption,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                TextField(
                  controller: noteController,
                  style: AppTheme.bodyMedium,
                  decoration: InputDecoration(
                    labelText: 'Note (Optional)',
                    labelStyle: AppTheme.caption,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.cardBorder),
                    ),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                await context.read<IncidentProvider>().updateIncidentStatus(
                      incident.id,
                      selectedStatus,
                      note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                    );
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Status updated to ${_getStatusLabel(selectedStatus)}'),
                      backgroundColor: AppTheme.successGreen,
                    ),
                  );
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Delete Incident', style: AppTheme.headingMedium),
        content: Text(
          'Are you sure you want to delete "${incident.title}"?',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              context.read<IncidentProvider>().deleteIncident(incident.id);
              Navigator.pop(ctx);
            },
            child: Text('Delete', style: AppTheme.bodyMedium.copyWith(color: AppTheme.primaryRed)),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(IncidentStatus status) {
    switch (status) {
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

  String _getStatusDescription(IncidentStatus status) {
    switch (status) {
      case IncidentStatus.pending:
        return 'Awaiting initial review';
      case IncidentStatus.underReview:
        return 'Being investigated';
      case IncidentStatus.verified:
        return 'Confirmed by sources';
      case IncidentStatus.resolved:
        return 'Issue addressed';
      case IncidentStatus.dismissed:
        return 'Invalid report';
    }
  }

  Color _getStatusColor(IncidentStatus status) {
    switch (status) {
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
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IncidentStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _getStatusColor().withValues(alpha: 0.3)),
      ),
      child: Text(
        _getStatusLabel(),
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _getStatusColor(),
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (status) {
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

  String _getStatusLabel() {
    switch (status) {
      case IncidentStatus.pending:
        return 'Pending';
      case IncidentStatus.underReview:
        return 'Review';
      case IncidentStatus.verified:
        return 'Verified';
      case IncidentStatus.resolved:
        return 'Resolved';
      case IncidentStatus.dismissed:
        return 'Dismissed';
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: color ?? (isDark ? AppTheme.darkTextPrimary : AppTheme.primaryDark),
        ),
      ),
    );
  }
}
