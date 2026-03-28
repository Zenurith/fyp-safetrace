import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../utils/app_theme.dart';
import '../../../data/models/incident_model.dart';
import '../../../data/services/analytics_service.dart';
import '../../providers/incident_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/flag_provider.dart';
import '../../providers/community_provider.dart';
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
    final pendingFlags = flagProvider.pendingCount;
    final pendingIncidents =
        incidents.where((i) => i.status == IncidentStatus.pending).length;
    final communityCount = communityProvider.communities.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page header
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard',
                style: AppTheme.headingLarge.copyWith(
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Real-time overview of SafeTrace platform activity.',
                style: AppTheme.caption,
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Stats grid
          _buildStatsGrid(analytics, columns, pendingFlags),
          const SizedBox(height: 28),

          // Quick actions + activity summary
          columns >= 3
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 300,
                      child: _buildQuickActions(
                          pendingFlags, pendingIncidents, communityCount),
                    ),
                    const SizedBox(width: 20),
                    Expanded(child: _buildActivitySummary(analytics)),
                  ],
                )
              : Column(
                  children: [
                    _buildQuickActions(
                        pendingFlags, pendingIncidents, communityCount),
                    const SizedBox(height: 20),
                    _buildActivitySummary(analytics),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(dynamic analytics, int columns, int pendingFlags) {
    final stats = [
      _StatData(
        label: 'Total Incidents',
        value: '${analytics.totalIncidents}',
        color: AppTheme.primaryDark,
        icon: Icons.warning_amber_rounded,
      ),
      _StatData(
        label: 'Active',
        value: '${analytics.activeIncidents}',
        color: AppTheme.warningOrange,
        icon: Icons.pending_actions,
      ),
      _StatData(
        label: 'Resolved',
        value: '${analytics.resolvedIncidents}',
        color: AppTheme.successGreen,
        icon: Icons.check_circle_outline,
      ),
      _StatData(
        label: 'Last 24 Hours',
        value: '${analytics.incidentsLast24h}',
        color: AppTheme.primaryRed,
        icon: Icons.schedule,
      ),
      _StatData(
        label: 'Total Users',
        value: _loadingUsers ? '—' : '$_totalUsers',
        color: AppTheme.primaryDark,
        icon: Icons.people_outline,
      ),
      _StatData(
        label: 'Pending Flags',
        value: '$pendingFlags',
        color: AppTheme.warningOrange,
        icon: Icons.flag_outlined,
      ),
    ];

    if (columns >= 3) {
      // Desktop: 2×3 data grid inside a single bordered card
      return Container(
        decoration: AppTheme.cardDecoration,
        child: Column(
          children: [
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(child: _StatTile(stats[0])),
                  Container(width: 1, color: AppTheme.cardBorder),
                  Expanded(child: _StatTile(stats[1])),
                  Container(width: 1, color: AppTheme.cardBorder),
                  Expanded(child: _StatTile(stats[2])),
                ],
              ),
            ),
            Container(height: 1, color: AppTheme.cardBorder),
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(child: _StatTile(stats[3])),
                  Container(width: 1, color: AppTheme.cardBorder),
                  Expanded(child: _StatTile(stats[4])),
                  Container(width: 1, color: AppTheme.cardBorder),
                  Expanded(child: _StatTile(stats[5])),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Tablet / mobile: 2-column card grid
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.0,
      children: stats
          .map((s) => Container(
                decoration: AppTheme.cardDecoration,
                child: _StatTile(s),
              ))
          .toList(),
    );
  }

  Widget _buildQuickActions(
      int pendingFlags, int pendingIncidents, int communityCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(label: 'Quick Actions'),
        const SizedBox(height: 12),
        Container(
          decoration: AppTheme.cardDecoration,
          child: Column(
            children: [
              _ActionRow(
                icon: Icons.flag_rounded,
                label: 'Review Flags',
                count: pendingFlags,
                color: AppTheme.warningOrange,
                onTap: () => widget.onNavigate?.call(4),
              ),
              Container(height: 1, color: AppTheme.cardBorder),
              _ActionRow(
                icon: Icons.groups_rounded,
                label: 'Communities',
                count: communityCount,
                color: AppTheme.primaryDark,
                onTap: () => widget.onNavigate?.call(3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivitySummary(dynamic analytics) {
    final total =
        analytics.totalIncidents > 0 ? analytics.totalIncidents : 1;
    final resolutionRate = analytics.totalIncidents > 0
        ? analytics.resolvedIncidents / analytics.totalIncidents
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(label: 'Activity Summary'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.cardDecoration,
          child: Column(
            children: [
              _ActivityBar(
                label: 'Incidents this week',
                value: '${analytics.incidentsLast7d}',
                proportion:
                    (analytics.incidentsLast7d / total).clamp(0.0, 1.0),
                color: AppTheme.primaryRed,
              ),
              const SizedBox(height: 20),
              _ActivityBar(
                label: 'Resolution rate',
                value: analytics.totalIncidents > 0
                    ? '${(resolutionRate * 100).toStringAsFixed(1)}%'
                    : 'N/A',
                proportion: resolutionRate.clamp(0.0, 1.0),
                color: AppTheme.successGreen,
              ),
              const SizedBox(height: 20),
              _MetricRow(
                label: 'Avg. resolution time',
                value:
                    '${analytics.averageResolutionDays.toStringAsFixed(1)} days',
                icon: Icons.timer_outlined,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Data model ─────────────────────────────────────────────────────────────

class _StatData {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatData({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
}

// ─── Widgets ─────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final _StatData data;
  const _StatTile(this.data);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: data.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                data.label.toUpperCase(),
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            data.value,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: AppTheme.primaryDark,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(height: 1, color: AppTheme.cardBorder),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.primaryDark,
                ),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: count > 0
                    ? color.withValues(alpha: 0.1)
                    : AppTheme.backgroundGrey,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: count > 0 ? color : AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right,
                size: 16, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _ActivityBar extends StatelessWidget {
  final String label;
  final String value;
  final double proportion;
  final Color color;

  const _ActivityBar({
    required this.label,
    required this.value,
    required this.proportion,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
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
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Container(
                  width: constraints.maxWidth,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  width: constraints.maxWidth * proportion,
                  height: 4,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 10),
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
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryDark,
          ),
        ),
      ],
    );
  }
}
