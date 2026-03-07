import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/incident_model.dart';
import '../../../utils/app_theme.dart';
import '../../providers/incident_provider.dart';

class AdminIncidentsTab extends StatefulWidget {
  const AdminIncidentsTab({super.key});

  @override
  State<AdminIncidentsTab> createState() => _AdminIncidentsTabState();
}

class _AdminIncidentsTabState extends State<AdminIncidentsTab> {
  String _searchQuery = '';
  IncidentStatus? _statusFilter;
  String _dateFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IncidentProvider>().startListeningAll();
    });
  }

  List<IncidentModel> _filterIncidents(List<IncidentModel> incidents) {
    return incidents.where((incident) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!incident.title.toLowerCase().contains(query) &&
            !incident.address.toLowerCase().contains(query) &&
            !incident.description.toLowerCase().contains(query)) {
          return false;
        }
      }

      if (_dateFilter != 'all') {
        final now = DateTime.now();
        DateTime cutoff;
        switch (_dateFilter) {
          case '7days':
            cutoff = now.subtract(const Duration(days: 7));
            break;
          case '30days':
            cutoff = now.subtract(const Duration(days: 30));
            break;
          default:
            cutoff = DateTime(2000);
        }
        if (incident.reportedAt.isBefore(cutoff)) return false;
      }

      if (_statusFilter != null && incident.status != _statusFilter) {
        return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final incidentProvider = context.watch<IncidentProvider>();
    final incidents = _filterIncidents(incidentProvider.allIncidents);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Column(
            children: [
              TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                style: AppTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Search incidents...',
                  hintStyle: AppTheme.caption,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.cardBorder),
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All Status',
                      isSelected: _statusFilter == null,
                      onTap: () => setState(() => _statusFilter = null),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Pending',
                      isSelected: _statusFilter == IncidentStatus.pending,
                      color: AppTheme.warningOrange,
                      onTap: () =>
                          setState(() => _statusFilter = IncidentStatus.pending),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Verified',
                      isSelected: _statusFilter == IncidentStatus.verified,
                      color: AppTheme.successGreen,
                      onTap: () =>
                          setState(() => _statusFilter = IncidentStatus.verified),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Resolved',
                      isSelected: _statusFilter == IncidentStatus.resolved,
                      color: AppTheme.successGreen,
                      onTap: () =>
                          setState(() => _statusFilter = IncidentStatus.resolved),
                    ),
                    const SizedBox(width: 16),
                    _FilterChip(
                      label: 'All Time',
                      isSelected: _dateFilter == 'all',
                      onTap: () => setState(() => _dateFilter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: '7 Days',
                      isSelected: _dateFilter == '7days',
                      onTap: () => setState(() => _dateFilter = '7days'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: '30 Days',
                      isSelected: _dateFilter == '30days',
                      onTap: () => setState(() => _dateFilter = '30days'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('${incidents.length} incidents', style: AppTheme.caption),
          ),
        ),
        Expanded(
          child: incidents.isEmpty
              ? Center(
                  child: Text(
                    'No incidents found',
                    style:
                        AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: incidents.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _IncidentCard(incident: incidents[index]),
                ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppTheme.primaryDark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? chipColor.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? chipColor : AppTheme.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
            color: isSelected ? chipColor : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  final IncidentModel incident;

  const _IncidentCard({required this.incident});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.categoryColor(incident.categoryLabel)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: AppTheme.categoryColor(incident.categoryLabel),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident.title,
                      style: AppTheme.headingSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${incident.categoryLabel}  •  ${incident.severityLabel}',
                      style: AppTheme.caption,
                    ),
                  ],
                ),
              ),
              _StatusChip(status: incident.status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  incident.address,
                  style: AppTheme.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _ActionButton(
                icon: Icons.edit_outlined,
                onTap: () => _showStatusDialog(context),
              ),
              const SizedBox(width: 4),
              _ActionButton(
                icon: Icons.delete_outline,
                color: AppTheme.primaryRed,
                onTap: () => _showDeleteDialog(context),
              ),
            ],
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
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(incident.title,
                      style: AppTheme.headingSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(incident.address,
                      style: AppTheme.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 16),
                  ...IncidentStatus.values.map((status) {
                    final isSelected = selectedStatus == status;
                    final color = _getStatusColor(status);
                    return GestureDetector(
                      onTap: () => setState(() => selectedStatus = status),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? color : AppTheme.cardBorder,
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
                                  color: isSelected ? color : AppTheme.cardBorder,
                                  width: 2,
                                ),
                                color:
                                    isSelected ? color : Colors.transparent,
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check,
                                      size: 14, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_getStatusLabel(status),
                                      style: AppTheme.bodyMedium
                                          .copyWith(fontWeight: FontWeight.w700)),
                                  Text(_getStatusDescription(status),
                                      style: AppTheme.caption),
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style:
                      AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                await context.read<IncidentProvider>().updateIncidentStatus(
                      incident.id,
                      selectedStatus,
                      note: noteController.text.trim().isEmpty
                          ? null
                          : noteController.text.trim(),
                    );
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        'Status updated to ${_getStatusLabel(selectedStatus)}'),
                    backgroundColor: AppTheme.successGreen,
                  ));
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
            child: Text('Cancel',
                style:
                    AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              context.read<IncidentProvider>().deleteIncident(incident.id);
              Navigator.pop(ctx);
            },
            child: Text('Delete',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.primaryRed)),
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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Icon(icon, size: 18, color: color ?? AppTheme.primaryDark),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _getColor().withValues(alpha: 0.3)),
      ),
      child: Text(
        _getLabel(),
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _getColor(),
        ),
      ),
    );
  }

  Color _getColor() {
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

  String _getLabel() {
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
