import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/audit_log_model.dart';
import '../../../data/models/community_model.dart';
import '../../../data/models/flag_model.dart';
import '../../../data/repositories/audit_log_repository.dart';
import '../../../data/repositories/community_repository.dart';
import '../../../data/repositories/user_repository.dart';
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
    _tabController = TabController(length: 4, vsync: this);

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
    // Community-type flags reviewed by admin.
    final communityFlags = flagProvider.flags
        .where((f) => f.targetType == FlagTargetType.community)
        .toList();
    // User flags escalated by community staff — pending admin action.
    final escalatedFlags = flagProvider.escalatedFlags;
    final pendingFlags =
        communityFlags.where((f) => f.status == FlagStatus.pending).toList();
    final reviewedFlags =
        communityFlags.where((f) => f.status != FlagStatus.pending).toList();
    // All community flags + all escalated flags (any status), sorted newest first.
    final allEscalated = flagProvider.flags
        .where((f) => f.escalatedToAdmin)
        .toList();
    final allFlags = [...communityFlags, ...allEscalated]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

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
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Escalated'),
                    if (escalatedFlags.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryDark,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${escalatedFlags.length}',
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
                    _EscalatedFlagsList(flags: escalatedFlags),
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

class _FlagCard extends StatefulWidget {
  final FlagModel flag;
  final bool showActions;

  const _FlagCard({required this.flag, required this.showActions});

  @override
  State<_FlagCard> createState() => _FlagCardState();
}

class _FlagCardState extends State<_FlagCard> {
  CommunityModel? _community;
  bool _communityLoaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.flag.targetType == FlagTargetType.community) {
      CommunityRepository().getById(widget.flag.targetId).then((c) {
        debugPrint('[FlagCard] community fetch result: ${c?.name} (id: ${widget.flag.targetId})');
        if (mounted) setState(() { _community = c; _communityLoaded = true; });
      }).catchError((e) {
        debugPrint('[FlagCard] community fetch error: $e (id: ${widget.flag.targetId})');
        if (mounted) setState(() => _communityLoaded = true);
      });
    }
  }

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
                  color: _getTargetColor(widget.flag.targetType).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getTargetIcon(widget.flag.targetType),
                  color: _getTargetColor(widget.flag.targetType),
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
                          widget.flag.targetTypeLabel,
                          style: AppTheme.headingSmall.copyWith(
                            color: AppTheme.primaryDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusChip(status: widget.flag.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Reported by ${widget.flag.reporterName} • ${widget.flag.timeAgo}',
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Actions
              if (widget.showActions) ...[
                if (widget.flag.targetType == FlagTargetType.community)
                  TextButton(
                    onPressed: () => _showDeleteCommunityDialog(context),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.primaryRed),
                    child: const Text(
                      'Delete Community',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
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
                  widget.flag.reason,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.primaryDark,
                  ),
                ),
                if (widget.flag.details != null && widget.flag.details!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.flag.details!,
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Resolution info (if resolved)
          if (widget.flag.status != FlagStatus.pending && widget.flag.resolutionNote != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getStatusColor(widget.flag.status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getStatusColor(widget.flag.status).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resolution Note',
                    style: AppTheme.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _getStatusColor(widget.flag.status),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.flag.resolutionNote!,
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Community info / Target ID reference
          const SizedBox(height: 8),
          if (widget.flag.targetType == FlagTargetType.community) ...[
            Row(
              children: [
                const Icon(Icons.groups_outlined, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _community?.name ?? (_communityLoaded ? 'Unknown Community' : 'Loading...'),
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.primaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_community != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    '${_community!.memberCount} members',
                    style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  'Community ID: ',
                  style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                ),
                Expanded(
                  child: Text(
                    widget.flag.targetId,
                    style: AppTheme.caption.copyWith(
                      fontFamily: 'monospace',
                      color: AppTheme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ] else
            Row(
              children: [
                Text(
                  'Target ID: ',
                  style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                ),
                Expanded(
                  child: Text(
                    widget.flag.targetId,
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

  void _showDeleteCommunityDialog(BuildContext context) {
    final currentUser = context.read<UserProvider>().currentUser;
    final communityName = _community?.name ?? 'this community';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Delete Community',
          style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryRed),
        ),
        content: SizedBox(
          width: 400,
          child: RichText(
            text: TextSpan(
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
              children: [
                const TextSpan(text: 'You are about to permanently delete '),
                TextSpan(
                  text: '"$communityName"',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(
                  text: ' and remove all its members. This action cannot be undone.',
                ),
              ],
            ),
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
              try {
                await CommunityRepository().delete(widget.flag.targetId);
                if (!context.mounted) return;
                await context.read<FlagProvider>().resolveFlag(
                      widget.flag.id,
                      resolvedBy: currentUser?.id,
                      note: 'Community deleted by administrator.',
                    );
                if (currentUser != null) {
                  AuditLogRepository().create(AuditLogModel(
                    id: '',
                    adminId: currentUser.id,
                    adminName: currentUser.name,
                    action: 'Deleted community',
                    targetType: 'community',
                    targetId: widget.flag.targetId,
                    detail: 'Community "$communityName" deleted via flag review.',
                    timestamp: DateTime.now(),
                  ));
                }
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Community deleted'),
                      backgroundColor: AppTheme.primaryRed,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete community: $e'),
                      backgroundColor: AppTheme.primaryRed,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
            child: const Text('Delete Community'),
          ),
        ],
      ),
    );
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
              final note = noteController.text.trim();
              Navigator.pop(ctx);
              final success = await context.read<FlagProvider>().resolveFlag(
                    widget.flag.id,
                    resolvedBy: currentUser?.id,
                    note: note.isEmpty ? null : note,
                  );
              if (success && context.mounted) {
                if (currentUser != null) {
                  AuditLogRepository().create(AuditLogModel(
                    id: '',
                    adminId: currentUser.id,
                    adminName: currentUser.name,
                    action: 'Resolved flag',
                    targetType: 'flag',
                    targetId: widget.flag.id,
                    detail: note.isEmpty
                        ? 'Reason: ${widget.flag.reason}'
                        : note,
                    timestamp: DateTime.now(),
                  ));
                }
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
              final note = noteController.text.trim();
              Navigator.pop(ctx);
              final success = await context.read<FlagProvider>().dismissFlag(
                    widget.flag.id,
                    resolvedBy: currentUser?.id,
                    note: note.isEmpty ? null : note,
                  );
              if (success && context.mounted) {
                if (currentUser != null) {
                  AuditLogRepository().create(AuditLogModel(
                    id: '',
                    adminId: currentUser.id,
                    adminName: currentUser.name,
                    action: 'Dismissed flag',
                    targetType: 'flag',
                    targetId: widget.flag.id,
                    detail: note.isEmpty
                        ? 'Reason: ${widget.flag.reason}'
                        : note,
                    timestamp: DateTime.now(),
                  ));
                }
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

// ── Escalated flags list ──────────────────────────────────────────────────────

class _EscalatedFlagsList extends StatelessWidget {
  final List<FlagModel> flags;

  const _EscalatedFlagsList({required this.flags});

  @override
  Widget build(BuildContext context) {
    if (flags.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.admin_panel_settings_outlined,
                size: 64,
                color: AppTheme.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('No escalated reports',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
            const SizedBox(height: 4),
            Text('Community managers have not escalated any user reports.',
                style: AppTheme.caption.copyWith(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: flags.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) =>
          _EscalatedFlagCard(flag: flags[index]),
    );
  }
}

class _EscalatedFlagCard extends StatelessWidget {
  final FlagModel flag;

  const _EscalatedFlagCard({required this.flag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecorationFor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryDark.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.admin_panel_settings_outlined,
                    color: AppTheme.primaryDark, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('User Report — Escalated',
                            style: AppTheme.headingSmall
                                .copyWith(color: AppTheme.primaryDark)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryDark.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color:
                                    AppTheme.primaryDark.withValues(alpha: 0.3)),
                          ),
                          child: const Text(
                            'ESCALATED',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Escalated by community staff · ${flag.timeAgo}',
                      style:
                          AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              // Actions
              TextButton(
                onPressed: () => _showTempBanDialog(context),
                style: TextButton.styleFrom(foregroundColor: AppTheme.warningOrange),
                child: const Text('Temp Ban',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
              TextButton(
                onPressed: () => _showPermaBanDialog(context),
                style: TextButton.styleFrom(foregroundColor: AppTheme.primaryRed),
                child: const Text('Perma Ban',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
              TextButton(
                onPressed: () => _showResolveDialog(context),
                style: TextButton.styleFrom(foregroundColor: AppTheme.successGreen),
                child: const Text('Resolve',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
              TextButton(
                onPressed: () => _showDismissDialog(context),
                style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
                child: const Text('Dismiss',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Original report reason ────────────────────────────────────────
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
                Text('Report Reason',
                    style: AppTheme.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                Text(flag.reason,
                    style: AppTheme.bodyMedium
                        .copyWith(color: AppTheme.primaryDark)),
                if (flag.details != null && flag.details!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(flag.details!,
                      style: AppTheme.bodyMedium
                          .copyWith(color: AppTheme.textSecondary)),
                ],
              ],
            ),
          ),

          // ── Escalation note ──────────────────────────────────────────────
          if (flag.resolutionNote != null &&
              flag.resolutionNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryDark.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppTheme.primaryDark.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Staff Escalation Note',
                      style: AppTheme.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryDark)),
                  const SizedBox(height: 4),
                  Text(flag.resolutionNote!,
                      style: AppTheme.bodyMedium
                          .copyWith(color: AppTheme.primaryDark)),
                ],
              ),
            ),
          ],

          // ── Context IDs ──────────────────────────────────────────────────
          const SizedBox(height: 8),
          _ContextRow(label: 'User ID', value: flag.targetId),
          if (flag.communityId != null)
            _ContextRow(label: 'Community ID', value: flag.communityId!),
          if (flag.escalatedBy != null)
            _ContextRow(label: 'Escalated by', value: flag.escalatedBy!),
        ],
      ),
    );
  }

  void _showTempBanDialog(BuildContext context) {
    final reasonController = TextEditingController();
    final currentUser = context.read<UserProvider>().currentUser;
    int selectedDays = 7;
    const durations = [1, 3, 7, 14, 30];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Temporarily Suspend User',
              style: AppTheme.headingMedium.copyWith(color: AppTheme.warningOrange)),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The user will be blocked from accessing SafeTrace for the selected period.',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                Text('Suspension Duration',
                    style: AppTheme.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: durations.map((days) {
                    final selected = selectedDays == days;
                    return ChoiceChip(
                      label: Text('$days ${days == 1 ? 'day' : 'days'}',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: selected ? Colors.white : AppTheme.primaryDark,
                          )),
                      selected: selected,
                      selectedColor: AppTheme.warningOrange,
                      backgroundColor: AppTheme.backgroundGrey,
                      side: BorderSide(
                          color: selected
                              ? AppTheme.warningOrange
                              : AppTheme.cardBorder),
                      onSelected: (_) => setModalState(() => selectedDays = days),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  style: AppTheme.bodyMedium,
                  decoration: InputDecoration(
                    labelText: 'Reason',
                    hintText: 'Describe the behaviour that warrants suspension...',
                    labelStyle: AppTheme.caption,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.cardBorder)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.cardBorder)),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final reason = reasonController.text.trim().isEmpty
                    ? 'Suspended by administrator.'
                    : reasonController.text.trim();
                final until = DateTime.now().add(Duration(days: selectedDays));
                final days = selectedDays;
                Navigator.pop(ctx);
                try {
                  await UserRepository().suspendUser(flag.targetId, until);
                  if (!context.mounted) return;
                  final note =
                      'User suspended for $days ${days == 1 ? 'day' : 'days'}. $reason';
                  await context.read<FlagProvider>().resolveFlag(
                        flag.id,
                        resolvedBy: currentUser?.id,
                        note: note,
                      );
                  if (currentUser != null && context.mounted) {
                    AuditLogRepository().create(AuditLogModel(
                      id: '',
                      adminId: currentUser.id,
                      adminName: currentUser.name,
                      action: 'Suspended user ($days days)',
                      targetType: 'user',
                      targetId: flag.targetId,
                      detail: note,
                      timestamp: DateTime.now(),
                    ));
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          'User suspended for $days ${days == 1 ? 'day' : 'days'}'),
                      backgroundColor: AppTheme.warningOrange,
                    ));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Failed to suspend user: $e'),
                      backgroundColor: AppTheme.primaryRed,
                    ));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warningOrange),
              child: const Text('Suspend User'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPermaBanDialog(BuildContext context) {
    final reasonController = TextEditingController();
    final currentUser = context.read<UserProvider>().currentUser;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Permanently Ban User',
              style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryRed)),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.primaryRed.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppTheme.primaryRed, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This permanently blocks the user from SafeTrace. This action cannot be undone from this screen.',
                          style: AppTheme.caption.copyWith(color: AppTheme.primaryRed),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  style: AppTheme.bodyMedium,
                  onChanged: (_) => setModalState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Ban Reason (required)',
                    hintText: 'Describe the behaviour that warrants a permanent ban...',
                    labelStyle: AppTheme.caption,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.cardBorder)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.cardBorder)),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: reasonController.text.trim().isEmpty
                  ? null
                  : () async {
                      final reason = reasonController.text.trim();
                      Navigator.pop(ctx);
                      try {
                        await UserRepository().banUser(flag.targetId, reason);
                        if (!context.mounted) return;
                        final note = 'User permanently banned. $reason';
                        await context.read<FlagProvider>().resolveFlag(
                              flag.id,
                              resolvedBy: currentUser?.id,
                              note: note,
                            );
                        if (currentUser != null && context.mounted) {
                          AuditLogRepository().create(AuditLogModel(
                            id: '',
                            adminId: currentUser.id,
                            adminName: currentUser.name,
                            action: 'Permanently banned user',
                            targetType: 'user',
                            targetId: flag.targetId,
                            detail: note,
                            timestamp: DateTime.now(),
                          ));
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('User permanently banned'),
                            backgroundColor: AppTheme.primaryRed,
                          ));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Failed to ban user: $e'),
                            backgroundColor: AppTheme.primaryRed,
                          ));
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
              child: const Text('Permanently Ban'),
            ),
          ],
        ),
      ),
    );
  }

  void _showResolveDialog(BuildContext context) {
    final noteController = TextEditingController();
    final currentUser = context.read<UserProvider>().currentUser;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Resolve Escalated Report', style: AppTheme.headingMedium),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mark as resolved. Record the action taken on the user\'s account.',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                style: AppTheme.bodyMedium,
                decoration: InputDecoration(
                  labelText: 'Resolution Note',
                  hintText: 'e.g. Account suspended for 7 days.',
                  labelStyle: AppTheme.caption,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.cardBorder)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.cardBorder)),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final note = noteController.text.trim();
              Navigator.pop(ctx);
              final ok = await context.read<FlagProvider>().resolveFlag(
                    flag.id,
                    resolvedBy: currentUser?.id,
                    note: note.isEmpty ? null : note,
                  );
              if (ok && context.mounted) {
                if (currentUser != null) {
                  AuditLogRepository().create(AuditLogModel(
                    id: '',
                    adminId: currentUser.id,
                    adminName: currentUser.name,
                    action: 'Resolved escalated report',
                    targetType: 'flag',
                    targetId: flag.id,
                    detail: note.isEmpty ? 'Reason: ${flag.reason}' : note,
                    timestamp: DateTime.now(),
                  ));
                }
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Report resolved'),
                  backgroundColor: AppTheme.successGreen,
                ));
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
        title: Text('Dismiss Escalated Report', style: AppTheme.headingMedium),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dismiss without action. Use this if the escalation was unwarranted.',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                style: AppTheme.bodyMedium,
                decoration: InputDecoration(
                  labelText: 'Reason for Dismissal',
                  hintText: 'Why is this escalation being dismissed...',
                  labelStyle: AppTheme.caption,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.cardBorder)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.cardBorder)),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final note = noteController.text.trim();
              Navigator.pop(ctx);
              final ok = await context.read<FlagProvider>().dismissFlag(
                    flag.id,
                    resolvedBy: currentUser?.id,
                    note: note.isEmpty ? null : note,
                  );
              if (ok && context.mounted) {
                if (currentUser != null) {
                  AuditLogRepository().create(AuditLogModel(
                    id: '',
                    adminId: currentUser.id,
                    adminName: currentUser.name,
                    action: 'Dismissed escalated report',
                    targetType: 'flag',
                    targetId: flag.id,
                    detail: note.isEmpty ? 'Reason: ${flag.reason}' : note,
                    timestamp: DateTime.now(),
                  ));
                }
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Report dismissed'),
                  backgroundColor: AppTheme.textSecondary,
                ));
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

class _ContextRow extends StatelessWidget {
  final String label;
  final String value;

  const _ContextRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Text('$label: ',
              style: AppTheme.caption.copyWith(color: AppTheme.textSecondary)),
          Expanded(
            child: Text(
              value,
              style: AppTheme.caption.copyWith(
                  fontFamily: 'monospace', color: AppTheme.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
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
