import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../utils/app_theme.dart';
import '../../../data/services/analytics_service.dart';
import '../../providers/incident_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/flag_provider.dart';
import '../../providers/community_provider.dart';
import '../../widgets/analytics/stats_card.dart';
import '../../widgets/admin_web/responsive_layout.dart';

class AdminDashboardPage extends StatefulWidget {
  final ValueChanged<int>? onNavigate;

  const AdminDashboardPage({super.key, this.onNavigate});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _totalUsers = 0;
  bool _loadingUsers = true;

  @override
  void initState() {
    super.initState();
    _loadUserCount();
  }

  Future<void> _loadUserCount() async {
    final users = await context.read<UserProvider>().fetchAllUsers();
    if (mounted) {
      setState(() {
        _totalUsers = users.length;
        _loadingUsers = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final incidentProvider = context.watch<IncidentProvider>();
    final flagProvider = context.watch<FlagProvider>();
    final communityProvider = context.watch<CommunityProvider>();
    final incidents = incidentProvider.allIncidents;
    final analytics = AnalyticsService.calculateAnalytics(incidents);
    final columns = ResponsiveLayout.getGridColumns(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: AppTheme.cardDecorationFor(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome to SafeTrace Admin',
                  style: AppTheme.headingLarge.copyWith(
                    color: AppTheme.primaryDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Monitor and manage your community safety platform from this dashboard.',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Quick stats grid
          Text(
            'Overview',
            style: AppTheme.headingMedium.copyWith(
              color: AppTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 16),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.2,
            children: [
              StatsCard(
                title: 'Total Incidents',
                value: '${analytics.totalIncidents}',
                icon: Icons.warning_amber_rounded,
                color: AppTheme.primaryDark,
              ),
              StatsCard(
                title: 'Active Incidents',
                value: '${analytics.activeIncidents}',
                icon: Icons.pending_actions,
                color: AppTheme.warningOrange,
              ),
              StatsCard(
                title: 'Resolved',
                value: '${analytics.resolvedIncidents}',
                icon: Icons.check_circle_outline,
                color: AppTheme.successGreen,
              ),
              StatsCard(
                title: 'Last 24 Hours',
                value: '${analytics.incidentsLast24h}',
                icon: Icons.schedule,
                color: AppTheme.primaryRed,
              ),
              StatsCard(
                title: 'Total Users',
                value: _loadingUsers ? '...' : '$_totalUsers',
                icon: Icons.people_outline,
                color: AppTheme.primaryDark,
              ),
              StatsCard(
                title: 'Pending Flags',
                value: '${flagProvider.pendingCount}',
                icon: Icons.flag_outlined,
                color: AppTheme.warningOrange,
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Quick actions
          Text(
            'Quick Actions',
            style: AppTheme.headingMedium.copyWith(
              color: AppTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 16),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _QuickActionCard(
                icon: Icons.flag_outlined,
                label: 'Review Flags',
                count: flagProvider.pendingCount,
                color: AppTheme.warningOrange,
                onTap: () => widget.onNavigate?.call(5),
              ),
              _QuickActionCard(
                icon: Icons.warning_amber_outlined,
                label: 'Pending Incidents',
                count: incidents.where((i) => i.status.index == 0).length,
                color: AppTheme.primaryRed,
                onTap: () => widget.onNavigate?.call(2),
              ),
              _QuickActionCard(
                icon: Icons.groups_outlined,
                label: 'Communities',
                count: communityProvider.communities.length,
                color: AppTheme.primaryDark,
                onTap: () => widget.onNavigate?.call(4),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Recent activity summary
          Text(
            'Activity Summary',
            style: AppTheme.headingMedium.copyWith(
              color: AppTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.cardDecorationFor(context),
            child: Column(
              children: [
                _SummaryRow(
                  label: 'Incidents this week',
                  value: '${analytics.incidentsLast7d}',
                  icon: Icons.trending_up,
),
                const Divider(height: 24),
                _SummaryRow(
                  label: 'Average resolution time',
                  value: '${analytics.averageResolutionDays.toStringAsFixed(1)} days',
                  icon: Icons.timer_outlined,
),
                const Divider(height: 24),
                _SummaryRow(
                  label: 'Resolution rate',
                  value: analytics.totalIncidents > 0
                      ? '${((analytics.resolvedIncidents / analytics.totalIncidents) * 100).toStringAsFixed(1)}%'
                      : 'N/A',
                  icon: Icons.check_circle_outline,
),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 180,
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecorationFor(context),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                    Text(
                      '$count items',
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppTheme.textSecondary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: AppTheme.headingSmall.copyWith(
            color: AppTheme.primaryDark,
          ),
        ),
      ],
    );
  }
}
