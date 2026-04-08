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

  List<String> _buildParticipants() {
    return {
      flag.reporterId,
      if (flag.escalatedBy != null) flag.escalatedBy!,
      ...flag.communityStaffIds,
    }.where((id) => id.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<FlagThreadProvider>().unreadForFlag(flag.id);

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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryDark.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: AppTheme.primaryDark
                                      .withValues(alpha: 0.4)),
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
                      style: AppTheme.caption
                          .copyWith(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),

              // Unread badge + Open Thread icon button
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline),
                    color: AppTheme.primaryDark,
                    tooltip: 'Open Thread',
                    onPressed: (flag.status == FlagStatus.pending || flag.escalatedToAdmin)
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FlagThreadScreen(
                                  flag: flag,
                                  participants: _buildParticipants(),
                                  senderRole: 'staff',
                                ),
                              ),
                            )
                        : null,
                  ),
                  if (unread > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryRed,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$unread',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
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
          if (flag.status != FlagStatus.pending &&
              flag.resolutionNote != null &&
              flag.resolutionNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Note: ${flag.resolutionNote}',
              style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
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
