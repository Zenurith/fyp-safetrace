part of '../community_manager_screen.dart';

// ── Community Flags Tab ──────────────────────────────────────────────────────

class _CommunityFlagsTab extends StatelessWidget {
  final String communityId;

  const _CommunityFlagsTab({required this.communityId});

  @override
  Widget build(BuildContext context) {
    final flags = context.watch<FlagProvider>().communityFlags;

    if (flags.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, size: 64, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            Text('No reports',
                style: TextStyle(fontSize: 18, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Text('No content has been reported in this community',
                style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryRed,
      onRefresh: () => context.read<FlagProvider>().refreshCommunityFlags(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: flags.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) =>
            _FlagCard(flag: flags[i], communityId: communityId),
      ),
    );
  }
}

class _FlagCard extends StatelessWidget {
  final FlagModel flag;
  final String communityId;

  const _FlagCard({required this.flag, required this.communityId});

  @override
  Widget build(BuildContext context) {
    final isPending = flag.status == FlagStatus.pending;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _typeColor(flag.targetType).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_typeIcon(flag.targetType),
                    size: 18, color: _typeColor(flag.targetType)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(flag.targetTypeLabel, style: AppTheme.headingSmall),
                        const SizedBox(width: 8),
                        _StatusChip(status: flag.status),
                        if (flag.escalatedToAdmin) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryDark.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: AppTheme.primaryDark.withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              'ESCALATED',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryDark,
                                fontFamily: AppTheme.fontFamily,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Reported by ${flag.reporterName} · ${flag.timeAgo}',
                      style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Reason box ──────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.backgroundGrey,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reason',
                    style: AppTheme.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                Text(flag.reason, style: AppTheme.bodyMedium),
                if (flag.details != null && flag.details!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(flag.details!,
                      style: AppTheme.bodyMedium
                          .copyWith(color: AppTheme.textSecondary)),
                ],
              ],
            ),
          ),

          // ── Resolution note (if actioned) ────────────────────────────────
          if (!isPending && flag.resolutionNote != null &&
              flag.resolutionNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Note: ${flag.resolutionNote}',
              style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
            ),
          ],

          // ── Action row (pending only, not yet escalated) ─────────────────
          if (isPending && !flag.escalatedToAdmin) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _dismissReport(context),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
                  child: const Text('Dismiss Report',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
                const SizedBox(width: 4),
                OutlinedButton(
                  onPressed: () => _showActionSheet(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryRed,
                    side: const BorderSide(color: AppTheme.primaryRed),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                  child: const Text('Take Action'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Action sheet ──────────────────────────────────────────────────────────

  void _showActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        switch (flag.targetType) {
          case FlagTargetType.incident:
            return _IncidentActionSheet(flag: flag, parentCtx: context);
          case FlagTargetType.comment:
            return _CommentActionSheet(flag: flag, parentCtx: context);
          case FlagTargetType.user:
            return _UserActionSheet(
                flag: flag, communityId: communityId, parentCtx: context);
          case FlagTargetType.community:
            return const SizedBox.shrink();
        }
      },
    );
  }

  Future<void> _dismissReport(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dismiss Report'),
        content: const Text(
            'Mark this report as dismissed? No action will be taken on the content.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Dismiss',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final staffId = context.read<UserProvider>().currentUser?.id;
    await context.read<FlagProvider>().dismissFlag(flag.id, resolvedBy: staffId,
        note: 'Report dismissed — no action required.');
  }

  IconData _typeIcon(FlagTargetType type) {
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

  Color _typeColor(FlagTargetType type) {
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
}

// ── Action Sheets ─────────────────────────────────────────────────────────────

class _IncidentActionSheet extends StatelessWidget {
  final FlagModel flag;
  final BuildContext parentCtx;

  const _IncidentActionSheet({required this.flag, required this.parentCtx});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Action on Incident Report', style: AppTheme.headingSmall),
          const SizedBox(height: 4),
          Text('Choose what to do with the reported incident.',
              style: AppTheme.caption.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          _ActionTile(
            icon: Icons.cancel_outlined,
            color: AppTheme.primaryRed,
            title: 'Dismiss Incident',
            subtitle: 'Mark the incident as dismissed. It will no longer appear on the map.',
            onTap: () => _dismissIncident(context),
          ),
        ],
      ),
    );
  }

  Future<void> _dismissIncident(BuildContext ctx) async {
    Navigator.pop(ctx);
    final confirmed = await showDialog<bool>(
      context: parentCtx,
      builder: (d) => AlertDialog(
        title: const Text('Dismiss Incident'),
        content: const Text(
            'Mark this incident as dismissed? It will be removed from the map.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(d, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
            child: const Text('Dismiss Incident'),
          ),
        ],
      ),
    );
    if (confirmed != true || !parentCtx.mounted) return;
    final staffId = parentCtx.read<UserProvider>().currentUser?.id ?? '';
    final ok = await parentCtx.read<IncidentProvider>().rejectCommunityIncident(flag.targetId, staffId);
    if (!parentCtx.mounted) return;
    if (ok) {
      await parentCtx.read<FlagProvider>().resolveFlag(flag.id,
          resolvedBy: staffId, note: 'Incident dismissed by community staff.');
    }
    if (!parentCtx.mounted) return;
    ScaffoldMessenger.of(parentCtx).showSnackBar(SnackBar(
      content: Text(ok ? 'Incident dismissed' : 'Failed to dismiss incident'),
      backgroundColor: ok ? AppTheme.successGreen : AppTheme.primaryRed,
    ));
  }
}

class _CommentActionSheet extends StatelessWidget {
  final FlagModel flag;
  final BuildContext parentCtx;

  const _CommentActionSheet({required this.flag, required this.parentCtx});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Action on Comment', style: AppTheme.headingSmall),
          const SizedBox(height: 4),
          Text('Choose what to do with the reported comment.',
              style: AppTheme.caption.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          _ActionTile(
            icon: Icons.delete_outline,
            color: AppTheme.primaryRed,
            title: 'Delete Comment',
            subtitle: 'Permanently remove this comment from the incident.',
            onTap: () => _deleteComment(context),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteComment(BuildContext ctx) async {
    Navigator.pop(ctx);
    final confirmed = await showDialog<bool>(
      context: parentCtx,
      builder: (d) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Permanently delete this comment? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(d, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !parentCtx.mounted) return;
    final staffId = parentCtx.read<UserProvider>().currentUser?.id ?? '';
    final ok = await parentCtx.read<CommentProvider>().deleteComment(flag.targetId);
    if (!parentCtx.mounted) return;
    if (ok) {
      await parentCtx.read<FlagProvider>().resolveFlag(flag.id,
          resolvedBy: staffId, note: 'Comment deleted by community staff.');
    }
    if (!parentCtx.mounted) return;
    ScaffoldMessenger.of(parentCtx).showSnackBar(SnackBar(
      content: Text(ok ? 'Comment deleted' : 'Failed to delete comment'),
      backgroundColor: ok ? AppTheme.successGreen : AppTheme.primaryRed,
    ));
  }
}

class _UserActionSheet extends StatelessWidget {
  final FlagModel flag;
  final String communityId;
  final BuildContext parentCtx;

  const _UserActionSheet(
      {required this.flag, required this.communityId, required this.parentCtx});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Action on User', style: AppTheme.headingSmall),
          const SizedBox(height: 4),
          Text('Choose what to do with the reported user.',
              style: AppTheme.caption.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          _ActionTile(
            icon: Icons.person_remove_outlined,
            color: AppTheme.warningOrange,
            title: 'Remove from Community',
            subtitle: 'Kick this user out. They can request to rejoin.',
            onTap: () => _removeUser(context),
          ),
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.block,
            color: AppTheme.primaryRed,
            title: 'Ban from Community',
            subtitle: 'Permanently ban this user from the community.',
            onTap: () => _banUser(context),
          ),
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.admin_panel_settings_outlined,
            color: AppTheme.primaryDark,
            title: 'Escalate to System Admin',
            subtitle: 'Report this behaviour to platform administrators for account-level action.',
            onTap: () => _escalateToAdmin(context),
          ),
        ],
      ),
    );
  }

  Future<void> _removeUser(BuildContext ctx) async {
    Navigator.pop(ctx);
    final confirmed = await showDialog<bool>(
      context: parentCtx,
      builder: (d) => AlertDialog(
        title: const Text('Remove User'),
        content: const Text('Remove this user from the community? They can request to rejoin.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(d, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warningOrange),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !parentCtx.mounted) return;
    await _doUserAction(parentCtx, ban: false);
  }

  Future<void> _banUser(BuildContext ctx) async {
    Navigator.pop(ctx);
    final confirmed = await showDialog<bool>(
      context: parentCtx,
      builder: (d) => AlertDialog(
        title: const Text('Ban User'),
        content: const Text('Permanently ban this user from the community? This cannot easily be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(d, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
            child: const Text('Ban'),
          ),
        ],
      ),
    );
    if (confirmed != true || !parentCtx.mounted) return;
    await _doUserAction(parentCtx, ban: true);
  }

  Future<void> _escalateToAdmin(BuildContext ctx) async {
    Navigator.pop(ctx); // close bottom sheet
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: parentCtx,
      builder: (d) => AlertDialog(
        title: const Text('Escalate to System Admin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will send the report to system administrators for platform-level review (e.g. account suspension).',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              style: AppTheme.bodyMedium,
              decoration: InputDecoration(
                labelText: 'Escalation note',
                hintText: 'Describe the behaviour and why admin action is needed...',
                labelStyle: AppTheme.caption,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(d, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryDark),
            child: const Text('Escalate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !parentCtx.mounted) return;
    final staffId = parentCtx.read<UserProvider>().currentUser?.id ?? '';
    final note = noteController.text.trim().isEmpty
        ? 'Escalated by community staff for admin review.'
        : noteController.text.trim();
    final ok = await parentCtx.read<FlagProvider>().escalateToAdmin(
          flag.id,
          escalatedBy: staffId,
          note: note,
        );
    if (!parentCtx.mounted) return;
    ScaffoldMessenger.of(parentCtx).showSnackBar(SnackBar(
      content: Text(ok ? 'Escalated to system admin' : 'Failed to escalate'),
      backgroundColor: ok ? AppTheme.primaryDark : AppTheme.primaryRed,
    ));
  }

  Future<void> _doUserAction(BuildContext ctx, {required bool ban}) async {
    final staffId = ctx.read<UserProvider>().currentUser?.id ?? '';
    // Look up the member document ID for this user in this community
    final membership = await CommunityRepository()
        .getUserMembership(communityId, flag.targetId);
    if (!ctx.mounted) return;
    if (membership == null) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
        content: Text('User is not a member of this community'),
        backgroundColor: AppTheme.warningOrange,
      ));
      return;
    }
    final provider = ctx.read<CommunityProvider>();
    final bool ok;
    final String note;
    if (ban) {
      ok = await provider.banMember(membership.id, communityId);
      note = 'User banned from community by staff.';
    } else {
      ok = await provider.removeMember(membership.id, communityId);
      note = 'User removed from community by staff.';
    }
    if (!ctx.mounted) return;
    if (ok) {
      await ctx.read<FlagProvider>().resolveFlag(flag.id,
          resolvedBy: staffId, note: note);
    }
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(ok
          ? (ban ? 'User banned from community' : 'User removed from community')
          : 'Action failed'),
      backgroundColor: ok ? AppTheme.successGreen : AppTheme.primaryRed,
    ));
  }
}

// ── Shared action tile ────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTheme.bodyMedium
                          .copyWith(fontWeight: FontWeight.w600, color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: AppTheme.caption
                          .copyWith(color: AppTheme.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: color.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final FlagStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case FlagStatus.pending:
        color = AppTheme.warningOrange;
        break;
      case FlagStatus.reviewed:
        color = AppTheme.primaryDark;
        break;
      case FlagStatus.resolved:
        color = AppTheme.successGreen;
        break;
      case FlagStatus.dismissed:
        color = AppTheme.textSecondary;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        _label(status),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
    );
  }

  String _label(FlagStatus s) {
    switch (s) {
      case FlagStatus.pending:
        return 'Pending';
      case FlagStatus.reviewed:
        return 'Reviewed';
      case FlagStatus.resolved:
        return 'Resolved';
      case FlagStatus.dismissed:
        return 'Dismissed';
    }
  }
}
