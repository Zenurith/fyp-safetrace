import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/community_model.dart';
import '../../../data/models/community_member_model.dart';
import '../../../data/models/user_model.dart';
import '../../../utils/app_theme.dart';
import '../../providers/community_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/user_avatar.dart';

class CommunitiesManagementPage extends StatefulWidget {
  const CommunitiesManagementPage({super.key});

  @override
  State<CommunitiesManagementPage> createState() => _CommunitiesManagementPageState();
}

class _CommunitiesManagementPageState extends State<CommunitiesManagementPage> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CommunityProvider>().startListening();
    });
  }

  List<CommunityModel> _filterCommunities(List<CommunityModel> communities) {
    if (_searchQuery.isEmpty) return communities;
    final query = _searchQuery.toLowerCase();
    return communities.where((c) {
      return c.name.toLowerCase().contains(query) ||
          c.address.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final communityProvider = context.watch<CommunityProvider>();
    final allCommunities = communityProvider.communities;
    final communities = _filterCommunities(allCommunities);

    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: AppTheme.cardBorder),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.primaryDark),
                  decoration: InputDecoration(
                    hintText: 'Search communities by name or location...',
                    hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                    prefixIcon: Icon(Icons.search, size: 20, color: AppTheme.textSecondary),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.cardBorder),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${communities.length} communities',
                style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),

        // Communities list
        Expanded(
          child: communityProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : communities.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.groups_outlined,
                            size: 64,
                            color: AppTheme.textSecondary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No communities match your search'
                                : 'No communities found',
                            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: communities.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _CommunityCard(community: communities[index]);
                      },
                    ),
        ),
      ],
    );
  }
}

// ── Community Card ─────────────────────────────────────────────────────────────

class _CommunityCard extends StatelessWidget {
  final CommunityModel community;

  const _CommunityCard({required this.community});

  void _openManage(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 620),
          child: _CommunityManageDialog(community: community),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecorationFor(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Community image/icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.primaryDark.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                image: community.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(community.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: community.imageUrl == null
                  ? const Icon(Icons.groups, color: AppTheme.primaryDark, size: 28)
                  : null,
            ),
            const SizedBox(width: 16),

            // Community info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          community.name,
                          style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryDark),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!community.isPublic) ...[
                        const SizedBox(width: 8),
                        _InlineBadge(
                          icon: Icons.lock,
                          label: 'Private',
                          color: AppTheme.warningOrange,
                        ),
                      ],
                      if (community.requiresApproval) ...[
                        const SizedBox(width: 6),
                        _InlineBadge(
                          icon: Icons.how_to_reg,
                          label: 'Approval Required',
                          color: AppTheme.primaryRed,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          community.address,
                          style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Stats
            _StatBadge(
              icon: Icons.people_outline,
              value: '${community.memberCount}',
              label: 'Members',
            ),
            const SizedBox(width: 16),
            _StatBadge(
              icon: Icons.radar,
              value: '${community.radius.toStringAsFixed(1)}km',
              label: 'Radius',
            ),
            const SizedBox(width: 16),

            // Manage button
            TextButton.icon(
              onPressed: () => _openManage(context),
              icon: const Icon(Icons.manage_accounts_outlined, size: 16),
              label: const Text('Manage'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryRed,
                backgroundColor: AppTheme.primaryRed.withValues(alpha: 0.08),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Manage Dialog ──────────────────────────────────────────────────────────────

class _CommunityManageDialog extends StatefulWidget {
  final CommunityModel community;

  const _CommunityManageDialog({required this.community});

  @override
  State<_CommunityManageDialog> createState() => _CommunityManageDialogState();
}

class _CommunityManageDialogState extends State<_CommunityManageDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.community.name,
                      style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryDark),
                    ),
                    Text(
                      'System Administration',
                      style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
        // Tabs
        TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryRed,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryRed,
          labelStyle: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Members'),
            Tab(text: 'Danger Zone'),
          ],
        ),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _AdminMembersContent(communityId: widget.community.id),
              _DangerZoneContent(community: widget.community),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Admin Members Content ──────────────────────────────────────────────────────

class _AdminMembersContent extends StatefulWidget {
  final String communityId;

  const _AdminMembersContent({required this.communityId});

  @override
  State<_AdminMembersContent> createState() => _AdminMembersContentState();
}

class _AdminMembersContentState extends State<_AdminMembersContent> {
  List<CommunityMemberModel> _members = [];
  bool _isLoading = true;
  final Map<String, UserModel?> _users = {};

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    final members = await context
        .read<CommunityProvider>()
        .getCommunityMembers(widget.communityId);
    if (!mounted) return;
    setState(() {
      _members = members;
      _isLoading = false;
    });
    if (members.isNotEmpty) {
      final ids = members.map((m) => m.userId).toList();
      context.read<UserProvider>().getUsersByIds(ids).then((fetched) {
        if (mounted) setState(() => _users.addAll(fetched));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_members.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              'No members yet',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _members.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final member = _members[index];
        return _AdminMemberItem(
          member: member,
          user: _users[member.userId],
          communityId: widget.communityId,
          onChanged: _loadMembers,
        );
      },
    );
  }
}

class _AdminMemberItem extends StatefulWidget {
  final CommunityMemberModel member;
  final UserModel? user;
  final String communityId;
  final VoidCallback onChanged;

  const _AdminMemberItem({
    required this.member,
    required this.user,
    required this.communityId,
    required this.onChanged,
  });

  @override
  State<_AdminMemberItem> createState() => _AdminMemberItemState();
}

class _AdminMemberItemState extends State<_AdminMemberItem> {
  bool _isProcessing = false;

  Future<void> _handleAction(String action) async {
    final provider = context.read<CommunityProvider>();
    final userName = widget.user?.name ?? 'this member';

    DateTime? tempBanUntil;

    if (action == 'temp_ban') {
      final duration = await showDialog<int>(
        context: context,
        builder: (ctx) => _TempBanDurationDialog(userName: userName),
      );
      if (duration == null) return;
      tempBanUntil = DateTime.now().add(Duration(days: duration));
    }

    if (action == 'ban') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Permanent Ban'),
          content: Text(
            'Permanently ban $userName from this community? They will not be able to rejoin.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ban', style: TextStyle(color: AppTheme.primaryRed)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (action == 'remove') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Remove Member'),
          content: Text('Remove $userName from this community?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove', style: TextStyle(color: AppTheme.primaryRed)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (!mounted) return;
    setState(() => _isProcessing = true);
    bool success = false;
    String successMsg = '';

    try {
      switch (action) {
        case 'temp_ban':
          success = await provider.banMember(widget.member.id, widget.communityId,
              bannedUntil: tempBanUntil);
          successMsg = 'Member temporarily banned';
          break;
        case 'ban':
          success = await provider.banMember(widget.member.id, widget.communityId);
          successMsg = 'Member permanently banned';
          break;
        case 'remove':
          success = await provider.removeMember(widget.member.id, widget.communityId);
          successMsg = 'Member removed';
          break;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isProcessing = false);
      if (success) {
        widget.onChanged();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(successMsg),
          backgroundColor: AppTheme.successGreen,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(provider.error ?? 'Action failed'),
          backgroundColor: AppTheme.primaryRed,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    final user = widget.user;
    final isBanned = member.isBanned;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isBanned ? AppTheme.primaryRed.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isBanned ? AppTheme.primaryRed.withValues(alpha: 0.3) : AppTheme.cardBorder,
        ),
      ),
      child: Row(
        children: [
          UserAvatar(
            photoUrl: user?.profilePhotoUrl,
            initials: user?.initials ?? '?',
            radius: 20,
            backgroundColor: member.isStaff ? AppTheme.primaryRed : AppTheme.primaryDark,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? '...',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.primaryDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (user != null)
                  Text(
                    user.handle,
                    style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                  ),
              ],
            ),
          ),
          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: member.isStaff
                  ? AppTheme.primaryRed.withValues(alpha: 0.1)
                  : AppTheme.backgroundGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              member.roleLabel,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: member.isStaff ? AppTheme.primaryRed : AppTheme.textSecondary,
              ),
            ),
          ),
          // Ban status badge
          if (isBanned) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                member.statusLabel,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryRed,
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          if (_isProcessing)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (!member.isOwner)
            PopupMenuButton<String>(
              onSelected: _handleAction,
              icon: Icon(Icons.more_vert, size: 18, color: AppTheme.textSecondary),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'temp_ban',
                  child: Row(
                    children: [
                      Icon(Icons.timer_outlined, size: 16, color: AppTheme.warningOrange),
                      SizedBox(width: 8),
                      Text('Temp Ban', style: TextStyle(color: AppTheme.warningOrange)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'ban',
                  child: Row(
                    children: [
                      Icon(Icons.block, size: 16, color: AppTheme.primaryRed),
                      SizedBox(width: 8),
                      Text('Permanent Ban', style: TextStyle(color: AppTheme.primaryRed)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(Icons.remove_circle_outline, size: 16),
                      SizedBox(width: 8),
                      Text('Remove from Community'),
                    ],
                  ),
                ),
              ],
            )
          else
            // Owner — no actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.backgroundGrey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Protected',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Temp Ban Duration Picker ───────────────────────────────────────────────────

class _TempBanDurationDialog extends StatefulWidget {
  final String userName;

  const _TempBanDurationDialog({required this.userName});

  @override
  State<_TempBanDurationDialog> createState() => _TempBanDurationDialogState();
}

class _TempBanDurationDialogState extends State<_TempBanDurationDialog> {
  int _selectedDays = 7;

  static const _options = [
    (label: '1 day', days: 1),
    (label: '3 days', days: 3),
    (label: '7 days', days: 7),
    (label: '30 days', days: 30),
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Temp Ban Duration'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How long should ${widget.userName} be banned from this community?',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          ..._options.map((opt) => RadioListTile<int>(
                title: Text(opt.label, style: AppTheme.bodyMedium),
                value: opt.days,
                groupValue: _selectedDays,
                activeColor: AppTheme.primaryRed,
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onChanged: (v) => setState(() => _selectedDays = v!),
              )),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selectedDays),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.warningOrange,
            foregroundColor: Colors.white,
          ),
          child: const Text('Apply Ban'),
        ),
      ],
    );
  }
}

// ── Danger Zone Content ────────────────────────────────────────────────────────

class _DangerZoneContent extends StatefulWidget {
  final CommunityModel community;

  const _DangerZoneContent({required this.community});

  @override
  State<_DangerZoneContent> createState() => _DangerZoneContentState();
}

class _DangerZoneContentState extends State<_DangerZoneContent> {
  bool _isDeleting = false;

  Future<void> _deleteCommunity() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Community'),
        content: Text(
          'Permanently delete "${widget.community.name}"? This will remove all members and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    final success = await context
        .read<CommunityProvider>()
        .deleteCommunity(widget.community.id);

    if (!mounted) return;
    setState(() => _isDeleting = false);

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('"${widget.community.name}" has been deleted'),
        backgroundColor: AppTheme.primaryRed,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to delete community'),
        backgroundColor: AppTheme.primaryRed,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final community = widget.community;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Community info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.backgroundGrey,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  community.name,
                  style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryDark),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        community.address,
                        style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _InfoChip(label: '${community.memberCount} members'),
                    const SizedBox(width: 8),
                    _InfoChip(label: '${community.radius.toStringAsFixed(1)} km radius'),
                    const SizedBox(width: 8),
                    _InfoChip(label: community.isPublic ? 'Public' : 'Private'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Danger zone header
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 18, color: AppTheme.primaryRed),
              const SizedBox(width: 6),
              Text(
                'Danger Zone',
                style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryRed),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Delete community action
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
              color: AppTheme.primaryRed.withValues(alpha: 0.03),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delete this community',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.primaryDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Permanently removes the community and all membership records. This cannot be undone.',
                        style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _isDeleting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryRed,
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: _deleteCommunity,
                        icon: const Icon(Icons.delete_forever_outlined, size: 16),
                        label: const Text('Delete Community'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppTheme.primaryDark,
        ),
      ),
    );
  }
}

// ── Shared Widgets ─────────────────────────────────────────────────────────────

class _InlineBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InlineBadge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatBadge({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text(
              value,
              style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryDark),
            ),
          ],
        ),
        Text(
          label,
          style: AppTheme.caption.copyWith(fontSize: 10, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
