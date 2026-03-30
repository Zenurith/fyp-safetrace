import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/audit_log_model.dart';
import '../../../data/models/flag_model.dart';
import '../../../data/repositories/audit_log_repository.dart';
import '../../../utils/app_theme.dart';
import '../../providers/flag_provider.dart';
import '../../providers/user_provider.dart';

class FlagsManagementPage extends StatefulWidget {
  const FlagsManagementPage({super.key});

  @override
  State<FlagsManagementPage> createState() => _FlagsManagementPageState();
}

class _FlagsManagementPageState extends State<FlagsManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Start listening to flags
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final flagProvider = context.read<FlagProvider>();
      flagProvider.startListening();
      flagProvider.startListeningPending();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flagProvider = context.watch<FlagProvider>();
    // Admin panel shows community reports only.
    // Incident/comment/user flags are handled by community managers.
    final allFlags = flagProvider.flags
        .where((f) => f.targetType == FlagTargetType.community)
        .toList();
    final pendingFlags = allFlags.where((f) => f.status == FlagStatus.pending).toList();
    final reviewedFlags = allFlags.where((f) => f.status != FlagStatus.pending).toList();

    return Column(
      children: [
        // Tab bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: AppTheme.cardBorder,
              ),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryRed,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primaryRed,
            indicatorWeight: 3,
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
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Pending'),
                    if (pendingFlags.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryRed,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${pendingFlags.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Tab(text: 'Reviewed (${reviewedFlags.length})'),
              Tab(text: 'All (${allFlags.length})'),
            ],
          ),
        ),

        // Tab content
        Expanded(
          child: flagProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _FlagsList(flags: pendingFlags, showActions: true),
                    _FlagsList(flags: reviewedFlags, showActions: false),
                    _FlagsList(flags: allFlags, showActions: false),
                  ],
                ),
        ),
      ],
    );
  }
}

class _FlagsList extends StatelessWidget {
  final List<FlagModel> flags;
  final bool showActions;

  const _FlagsList({required this.flags, required this.showActions});

  @override
  Widget build(BuildContext context) {
    if (flags.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.flag_outlined,
              size: 64,
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No flags found',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: flags.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _FlagCard(flag: flags[index], showActions: showActions);
      },
    );
  }
}

class _FlagCard extends StatelessWidget {
  final FlagModel flag;
  final bool showActions;

  const _FlagCard({required this.flag, required this.showActions});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecorationFor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Target type icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _getTargetColor(flag.targetType).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getTargetIcon(flag.targetType),
                  color: _getTargetColor(flag.targetType),
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),

              // Flag info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          flag.targetTypeLabel,
                          style: AppTheme.headingSmall.copyWith(
                            color: AppTheme.primaryDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusChip(status: flag.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Reported by ${flag.reporterName} • ${flag.timeAgo}',
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Actions
              if (showActions) ...[
                TextButton(
                  onPressed: () => _showResolveDialog(context),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.successGreen),
                  child: const Text(
                    'Resolve',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _showDismissDialog(context),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
                  child: const Text(
                    'Dismiss',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Reason
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.backgroundGrey,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reason',
                  style: AppTheme.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  flag.reason,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.primaryDark,
                  ),
                ),
                if (flag.details != null && flag.details!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    flag.details!,
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Resolution info (if resolved)
          if (flag.status != FlagStatus.pending && flag.resolutionNote != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getStatusColor(flag.status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getStatusColor(flag.status).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resolution Note',
                    style: AppTheme.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _getStatusColor(flag.status),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    flag.resolutionNote!,
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Target ID reference
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Target ID: ',
                style: AppTheme.caption.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              Expanded(
                child: Text(
                  flag.targetId,
                  style: AppTheme.caption.copyWith(
                    fontFamily: 'monospace',
                    color: AppTheme.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getTargetIcon(FlagTargetType type) {
    switch (type) {
      case FlagTargetType.incident:
        return Icons.warning_amber_rounded;
      case FlagTargetType.comment:
        return Icons.comment_outlined;
      case FlagTargetType.user:
        return Icons.person_outline;
      case FlagTargetType.community:
        return Icons.groups_outlined;
    }
  }

  Color _getTargetColor(FlagTargetType type) {
    switch (type) {
      case FlagTargetType.incident:
        return AppTheme.warningOrange;
      case FlagTargetType.comment:
        return AppTheme.primaryDark;
      case FlagTargetType.user:
        return AppTheme.primaryRed;
      case FlagTargetType.community:
        return AppTheme.warningOrange;
    }
  }

  Color _getStatusColor(FlagStatus status) {
    switch (status) {
      case FlagStatus.pending:
        return AppTheme.warningOrange;
      case FlagStatus.reviewed:
        return AppTheme.primaryDark;
      case FlagStatus.resolved:
        return AppTheme.successGreen;
      case FlagStatus.dismissed:
        return AppTheme.textSecondary;
    }
  }

  void _showResolveDialog(BuildContext context) {
    final noteController = TextEditingController();
    final currentUser = context.read<UserProvider>().currentUser;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Resolve Flag', style: AppTheme.headingMedium),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mark this flag as resolved. This indicates the issue has been addressed.',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                style: AppTheme.bodyMedium,
                decoration: InputDecoration(
                  labelText: 'Resolution Note',
                  hintText: 'Describe the action taken...',
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
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await context.read<FlagProvider>().resolveFlag(
                    flag.id,
                    resolvedBy: currentUser?.id,
                    note: noteController.text.trim().isEmpty
                        ? null
                        : noteController.text.trim(),
                  );
              if (success && context.mounted) {
                if (currentUser != null) {
                  AuditLogRepository().create(AuditLogModel(
                    id: '',
                    adminId: currentUser.id,
                    adminName: currentUser.name,
                    action: 'Resolved flag',
                    targetType: 'flag',
                    targetId: flag.id,
                    detail: noteController.text.trim().isEmpty
                        ? 'Reason: ${flag.reason}'
                        : noteController.text.trim(),
                    timestamp: DateTime.now(),
                  ));
                }
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Flag resolved'),
                    backgroundColor: AppTheme.successGreen,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successGreen),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
  }

  void _showDismissDialog(BuildContext context) {
    final noteController = TextEditingController();
    final currentUser = context.read<UserProvider>().currentUser;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Dismiss Flag', style: AppTheme.headingMedium),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dismiss this flag without taking action. Use this for invalid or false reports.',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                style: AppTheme.bodyMedium,
                decoration: InputDecoration(
                  labelText: 'Reason for Dismissal',
                  hintText: 'Why is this flag being dismissed...',
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
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await context.read<FlagProvider>().dismissFlag(
                    flag.id,
                    resolvedBy: currentUser?.id,
                    note: noteController.text.trim().isEmpty
                        ? null
                        : noteController.text.trim(),
                  );
              if (success && context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Flag dismissed'),
                    backgroundColor: AppTheme.textSecondary,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.textSecondary),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final FlagStatus status;

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
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _getColor(),
        ),
      ),
    );
  }

  Color _getColor() {
    switch (status) {
      case FlagStatus.pending:
        return AppTheme.warningOrange;
      case FlagStatus.reviewed:
        return AppTheme.primaryDark;
      case FlagStatus.resolved:
        return AppTheme.successGreen;
      case FlagStatus.dismissed:
        return AppTheme.textSecondary;
    }
  }

  String _getLabel() {
    switch (status) {
      case FlagStatus.pending:
        return 'PENDING';
      case FlagStatus.reviewed:
        return 'REVIEWED';
      case FlagStatus.resolved:
        return 'RESOLVED';
      case FlagStatus.dismissed:
        return 'DISMISSED';
    }
  }
}
