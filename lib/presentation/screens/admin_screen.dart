import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/user_model.dart';
import '../../utils/app_theme.dart';
import '../providers/incident_provider.dart';
import '../providers/user_provider.dart';

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
              leading: CircleAvatar(
                backgroundColor: user.isAdmin
                    ? AppTheme.primaryRed
                    : AppTheme.accentBlue,
                child: Text(
                  user.initials,
                  style: const TextStyle(color: Colors.white),
                ),
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
        return ListTile(
          leading: CircleAvatar(
            backgroundColor:
                AppTheme.categoryColor(incident.categoryLabel),
            child: const Icon(Icons.warning_amber_rounded,
                color: Colors.white, size: 20),
          ),
          title: Text(incident.title),
          subtitle: Text(
              '${incident.categoryLabel}  •  ${incident.severityLabel}'),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.primaryRed),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Incident'),
                  content: Text(
                      'Are you sure you want to delete "${incident.title}"?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        context
                            .read<IncidentProvider>()
                            .deleteIncident(incident.id);
                        Navigator.pop(ctx);
                      },
                      child: const Text('Delete',
                          style: TextStyle(color: AppTheme.primaryRed)),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
