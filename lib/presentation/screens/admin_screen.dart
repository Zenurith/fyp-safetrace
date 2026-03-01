import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/incident_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/category_model.dart';
import '../../utils/app_theme.dart';
import '../providers/incident_provider.dart';
import '../providers/user_provider.dart';
import '../providers/category_provider.dart';
import '../widgets/user_avatar.dart';
import '../widgets/user_moderation_dialog.dart';
import '../../data/services/analytics_service.dart';
import '../widgets/analytics/stats_card.dart';
import '../widgets/analytics/incident_trend_chart.dart';
import '../widgets/analytics/category_pie_chart.dart';
import '../widgets/analytics/severity_bar_chart.dart';
import '../widgets/export_dialog.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundGrey,
        appBar: AppBar(
          title: Text(
            'Admin Dashboard',
            style: AppTheme.headingMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: AppTheme.primaryDark,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Export Reports',
              onPressed: () => ExportDialog.show(context),
            ),
          ],
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: AppTheme.primaryRed,
            indicatorWeight: 3,
            isScrollable: true,
            labelStyle: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            unselectedLabelStyle: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w400,
              fontSize: 14,
            ),
            tabs: const [
              Tab(text: 'Users'),
              Tab(text: 'Incidents'),
              Tab(text: 'Categories'),
              Tab(text: 'Analytics'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _UsersTab(),
            _IncidentsTab(),
            _CategoriesTab(),
            _AnalyticsTab(),
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
          return Center(
            child: Text(
              'Error loading users',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            ),
          );
        }
        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return Center(
            child: Text(
              'No users found',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final user = users[index];
            return _UserCard(user: user, onRefresh: _refresh);
          },
        );
      },
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onRefresh;

  const _UserCard({required this.user, required this.onRefresh});

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
              Stack(
                children: [
                  UserAvatar(
                    photoUrl: user.profilePhotoUrl,
                    initials: user.initials,
                    radius: 24,
                    backgroundColor: user.isAdmin ? AppTheme.primaryRed : AppTheme.primaryDark,
                  ),
                  if (user.isBanned || user.isActivelySuspended)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: user.isBanned ? AppTheme.primaryRed : AppTheme.warningOrange,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(
                          user.isBanned ? Icons.block : Icons.timer,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.name,
                            style: AppTheme.headingSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (user.isBanned) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryRed,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'BANNED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ] else if (user.isActivelySuspended) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.warningOrange,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'SUSPENDED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.handle,
                      style: AppTheme.caption,
                    ),
                  ],
                ),
              ),
              _RoleChip(isAdmin: user.isAdmin),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${user.points} pts  •  ${user.reports} reports  •  Level ${user.level}',
                  style: AppTheme.caption,
                ),
              ),
              TextButton(
                onPressed: () async {
                  final newRole = user.isAdmin ? 'user' : 'admin';
                  await context.read<UserProvider>().setUserRole(user.id, newRole);
                  onRefresh();
                },
                style: TextButton.styleFrom(
                  foregroundColor: user.isAdmin ? AppTheme.warningOrange : AppTheme.successGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  user.isAdmin ? 'Demote' : 'Promote',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () async {
                  final result = await UserModerationDialog.show(context, user);
                  if (result == true) {
                    onRefresh();
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryRed,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Moderate',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final bool isAdmin;

  const _RoleChip({required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isAdmin ? AppTheme.primaryRed.withValues(alpha: 0.1) : AppTheme.backgroundGrey,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isAdmin ? AppTheme.primaryRed.withValues(alpha: 0.3) : AppTheme.cardBorder,
        ),
      ),
      child: Text(
        isAdmin ? 'Admin' : 'User',
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isAdmin ? AppTheme.primaryRed : AppTheme.textSecondary,
        ),
      ),
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
      return Center(
        child: Text(
          'No incidents found',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: incidents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final incident = incidents[index];
        return _IncidentCard(incident: incident);
      },
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
                  color: AppTheme.categoryColor(incident.categoryLabel).withValues(alpha: 0.1),
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
                        color: isSelected ? _getStatusColor(status).withValues(alpha: 0.1) : Colors.transparent,
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
        color: _getStatusColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
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

class _AnalyticsTab extends StatelessWidget {
  const _AnalyticsTab();

  @override
  Widget build(BuildContext context) {
    final incidentProvider = context.watch<IncidentProvider>();
    final incidents = incidentProvider.allIncidents;
    final analytics = AnalyticsService.calculateAnalytics(incidents);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats grid
          Row(
            children: [
              Expanded(
                child: StatsCard(
                  title: 'Total Incidents',
                  value: '${analytics.totalIncidents}',
                  icon: Icons.warning_amber_rounded,
                  color: AppTheme.primaryDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatsCard(
                  title: 'Active',
                  value: '${analytics.activeIncidents}',
                  icon: Icons.pending_actions,
                  color: AppTheme.warningOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatsCard(
                  title: 'Resolved',
                  value: '${analytics.resolvedIncidents}',
                  icon: Icons.check_circle_outline,
                  color: AppTheme.successGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatsCard(
                  title: 'Last 24h',
                  value: '${analytics.incidentsLast24h}',
                  icon: Icons.schedule,
                  color: AppTheme.primaryRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatsCard(
                  title: 'Last 7 Days',
                  value: '${analytics.incidentsLast7d}',
                  icon: Icons.date_range,
                  color: AppTheme.accentBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatsCard(
                  title: 'Avg Resolution',
                  value: '${analytics.averageResolutionDays.toStringAsFixed(1)}d',
                  icon: Icons.timer_outlined,
                  color: AppTheme.profilePurple,
                  subtitle: 'days',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Trend chart
          IncidentTrendChart(data: analytics.trendData),
          const SizedBox(height: 16),

          // Category and severity charts
          CategoryPieChart(data: analytics.categoryDistribution),
          const SizedBox(height: 16),
          SeverityBarChart(data: analytics.severityDistribution),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _CategoriesTab extends StatelessWidget {
  const _CategoriesTab();

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final categories = categoryProvider.categories;

    if (categoryProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (categoryProvider.error != null) {
      return Center(
        child: Text(
          'Error loading categories',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      body: categories.isEmpty
          ? Center(
              child: Text(
                'No categories found',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final category = categories[index];
                return _CategoryCard(category: category);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategoryDialog(context),
        backgroundColor: AppTheme.primaryRed,
        elevation: 0,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _CategoryDialog(
        onSave: (name, iconName, colorHex) async {
          final result = await context.read<CategoryProvider>().addCategory(
                name: name,
                iconName: iconName,
                colorHex: colorHex,
              );
          if (result != null && context.mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Category "$name" added'),
                backgroundColor: AppTheme.successGreen,
              ),
            );
          }
        },
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final CategoryModel category;

  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: category.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(category.icon, color: category.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(category.name, style: AppTheme.headingSmall),
                    if (category.isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundGrey,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Default',
                          style: AppTheme.caption.copyWith(fontSize: 10),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  category.isEnabled ? 'Enabled' : 'Disabled',
                  style: AppTheme.caption.copyWith(
                    color: category.isEnabled ? AppTheme.successGreen : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: category.isEnabled,
            activeTrackColor: AppTheme.successGreen,
            onChanged: (value) {
              context.read<CategoryProvider>().toggleCategoryEnabled(category.id);
            },
          ),
          if (!category.isDefault) ...[
            _ActionButton(
              icon: Icons.edit_outlined,
              onTap: () => _showEditDialog(context),
            ),
            const SizedBox(width: 4),
            _ActionButton(
              icon: Icons.delete_outline,
              color: AppTheme.primaryRed,
              onTap: () => _showDeleteDialog(context),
            ),
          ],
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _CategoryDialog(
        category: category,
        onSave: (name, iconName, colorHex) async {
          final updated = category.copyWith(
            name: name,
            iconName: iconName,
            colorHex: colorHex,
          );
          final result = await context.read<CategoryProvider>().updateCategory(updated);
          if (result && context.mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Category "$name" updated'),
                backgroundColor: AppTheme.successGreen,
              ),
            );
          }
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Delete Category', style: AppTheme.headingMedium),
        content: Text(
          'Are you sure you want to delete "${category.name}"?',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              final result = await context.read<CategoryProvider>().deleteCategory(category.id);
              if (result && context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Category "${category.name}" deleted'),
                    backgroundColor: AppTheme.successGreen,
                  ),
                );
              }
            },
            child: Text('Delete', style: AppTheme.bodyMedium.copyWith(color: AppTheme.primaryRed)),
          ),
        ],
      ),
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  final CategoryModel? category;
  final Function(String name, String iconName, String colorHex) onSave;

  const _CategoryDialog({this.category, required this.onSave});

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late TextEditingController _nameController;
  late String _selectedIcon;
  late String _selectedColor;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _selectedIcon = widget.category?.iconName ?? 'category';
    _selectedColor = widget.category?.colorHex ?? '#3182CE';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'shield':
        return Icons.shield;
      case 'construction':
        return Icons.construction;
      case 'visibility':
        return Icons.visibility;
      case 'directions_car':
        return Icons.directions_car;
      case 'eco':
        return Icons.eco;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'warning':
        return Icons.warning;
      case 'report':
        return Icons.report;
      case 'security':
        return Icons.security;
      case 'flash_on':
        return Icons.flash_on;
      case 'water_drop':
        return Icons.water_drop;
      case 'pets':
        return Icons.pets;
      default:
        return Icons.category;
    }
  }

  Color _getColor(String colorHex) {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.category != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        isEditing ? 'Edit Category' : 'Add Category',
        style: AppTheme.headingMedium,
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                style: AppTheme.bodyMedium,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Category Name',
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
              ),
              const SizedBox(height: 16),
              Text('Icon', style: AppTheme.headingSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CategoryModel.availableIcons.map((iconName) {
                  final isSelected = _selectedIcon == iconName;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = iconName),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _getColor(_selectedColor).withValues(alpha: 0.1)
                            : AppTheme.backgroundGrey,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? _getColor(_selectedColor) : AppTheme.cardBorder,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Icon(
                        _getIconData(iconName),
                        color: isSelected ? _getColor(_selectedColor) : AppTheme.textSecondary,
                        size: 22,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text('Color', style: AppTheme.headingSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CategoryModel.availableColors.map((colorHex) {
                  final isSelected = _selectedColor == colorHex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = colorHex),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _getColor(colorHex),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryDark : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundGrey,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getColor(_selectedColor).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getIconData(_selectedIcon),
                        color: _getColor(_selectedColor),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _nameController.text.isEmpty ? 'Preview' : _nameController.text,
                      style: AppTheme.headingSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _nameController.text.trim().isEmpty
              ? null
              : () {
                  widget.onSave(
                    _nameController.text.trim(),
                    _selectedIcon,
                    _selectedColor,
                  );
                },
          child: Text(isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
