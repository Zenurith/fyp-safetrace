import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/incident_model.dart';
import '../../data/models/user_model.dart';
import '../../utils/app_theme.dart';
import '../providers/incident_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/user_avatar.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          backgroundColor: AppTheme.primaryDark,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: AppTheme.primaryRed,
            tabs: [
              Tab(text: 'Users'),
              Tab(text: 'Incidents'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _UsersTab(),
            _IncidentsTab(),
          ],
        ),
      ),
    );
  }
}

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  late Future<List<UserModel>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = context.read<UserProvider>().fetchAllUsers();
  }

  void _refresh() {
    setState(() {
      _usersFuture = context.read<UserProvider>().fetchAllUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<UserModel>>(
      future: _usersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return const Center(child: Text('No users found.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              leading: UserAvatar(
                photoUrl: user.profilePhotoUrl,
                initials: user.initials,
                radius: 20,
                backgroundColor: user.isAdmin
                    ? AppTheme.primaryRed
                    : AppTheme.accentBlue,
              ),
              title: Text(user.name),
              subtitle: Text('${user.handle}  •  ${user.role}'),
              trailing: TextButton(
                onPressed: () async {
                  final newRole = user.isAdmin ? 'user' : 'admin';
                  await context
                      .read<UserProvider>()
                      .setUserRole(user.id, newRole);
                  _refresh();
                },
                child: Text(
                  user.isAdmin ? 'Demote' : 'Promote',
                  style: TextStyle(
                    color: user.isAdmin
                        ? AppTheme.warningOrange
                        : AppTheme.successGreen,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _IncidentsTab extends StatelessWidget {
  const _IncidentsTab();

  @override
  Widget build(BuildContext context) {
    final incidentProvider = context.watch<IncidentProvider>();
    final incidents = incidentProvider.incidents;

    if (incidents.isEmpty) {
      return const Center(child: Text('No incidents found.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: incidents.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final incident = incidents[index];
        return _IncidentListItem(incident: incident);
      },
    );
  }
}

class _IncidentListItem extends StatelessWidget {
  final IncidentModel incident;

  const _IncidentListItem({required this.incident});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppTheme.categoryColor(incident.categoryLabel),
        child: const Icon(Icons.warning_amber_rounded,
            color: Colors.white, size: 20),
      ),
      title: Text(incident.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${incident.categoryLabel}  •  ${incident.severityLabel}'),
          const SizedBox(height: 4),
          _StatusChip(status: incident.status),
        ],
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_note, color: AppTheme.accentBlue),
            onPressed: () => _showStatusDialog(context),
            tooltip: 'Update Status',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.primaryRed),
            onPressed: () => _showDeleteDialog(context),
            tooltip: 'Delete',
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
          title: const Text('Update Incident Status'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  incident.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  incident.address,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select Status:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                ...IncidentStatus.values.map((status) {
                  return RadioListTile<IncidentStatus>(
                    value: status,
                    groupValue: selectedStatus,
                    title: Text(_getStatusLabel(status)),
                    subtitle: Text(
                      _getStatusDescription(status),
                      style: const TextStyle(fontSize: 12),
                    ),
                    activeColor: _getStatusColor(status),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedStatus = value);
                      }
                    },
                  );
                }),
                const SizedBox(height: 16),
                TextField(
                  controller: noteController,
                  decoration: InputDecoration(
                    labelText: 'Status Note (Optional)',
                    hintText: 'Add a note about this status change...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
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
              child: const Text('Cancel'),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Status updated to ${_getStatusLabel(selectedStatus)}',
                      ),
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
        title: const Text('Delete Incident'),
        content: Text('Are you sure you want to delete "${incident.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<IncidentProvider>().deleteIncident(incident.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.primaryRed)),
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
        return 'Being investigated by authorities';
      case IncidentStatus.verified:
        return 'Confirmed by multiple sources';
      case IncidentStatus.resolved:
        return 'Issue has been addressed';
      case IncidentStatus.dismissed:
        return 'Invalid or false report';
    }
  }

  Color _getStatusColor(IncidentStatus status) {
    switch (status) {
      case IncidentStatus.pending:
        return Colors.orange;
      case IncidentStatus.underReview:
        return Colors.blue;
      case IncidentStatus.verified:
        return Colors.green;
      case IncidentStatus.resolved:
        return Colors.teal;
      case IncidentStatus.dismissed:
        return Colors.grey;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final IncidentStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _getStatusColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _getStatusColor().withValues(alpha: 0.5)),
      ),
      child: Text(
        _getStatusLabel(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _getStatusColor(),
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (status) {
      case IncidentStatus.pending:
        return Colors.orange;
      case IncidentStatus.underReview:
        return Colors.blue;
      case IncidentStatus.verified:
        return Colors.green;
      case IncidentStatus.resolved:
        return Colors.teal;
      case IncidentStatus.dismissed:
        return Colors.grey;
    }
  }

  String _getStatusLabel() {
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
}
