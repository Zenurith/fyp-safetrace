part of '../community_detail_screen.dart';

// ── Activity Tab ──────────────────────────────────────────────────────────────

class _ActivityTab extends StatefulWidget {
  final String communityId;

  const _ActivityTab({required this.communityId});

  @override
  State<_ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<_ActivityTab>
    with AutomaticKeepAliveClientMixin {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CommunityProvider>().loadActivityFeed(widget.communityId);
      }
    });
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final feed = context.watch<CommunityProvider>().activityFeed;

    if (feed.isEmpty) {
      return Center(
        child: _EmptyState(
          icon: Icons.history_outlined,
          message: 'No activity yet.\nActivity will appear here.',
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: feed.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _ActivityCard(activity: feed[index]),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final ActivityModel activity;

  const _ActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: activity.iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(activity.icon, size: 18, color: activity.iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              activity.description,
              style: AppTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(activity.timeAgo, style: AppTheme.caption),
        ],
      ),
    );
  }
}
