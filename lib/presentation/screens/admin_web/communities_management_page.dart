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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CommunityProvider>().loadPendingRequests(widget.community.id);
    });
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
                      'Community Management',
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
            Tab(text: 'Pending Requests'),
            Tab(text: 'Members'),
          ],
        ),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _PendingRequestsContent(communityId: widget.community.id),
              _MembersContent(communityId: widget.community.id),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Pending Requests Content ───────────────────────────────────────────────────

class _PendingRequestsContent extends StatefulWidget {
  final String communityId;

  const _PendingRequestsContent({required this.communityId});

  @override
  State<_PendingRequestsContent> createState() => _PendingRequestsContentState();
}

class _PendingRequestsContentState extends State<_PendingRequestsContent> {
  final Set<String> _requestedIds = {};
  final Map<String, UserModel?> _users = {};

  void _loadMissingUsers(List<CommunityMemberModel> requests) {
    final missing = requests
        .map((r) => r.userId)
        .where((id) => !_requestedIds.contains(id))
        .toList();
    if (missing.isEmpty) return;
    for (final id in missing) {
      _requestedIds.add(id);
    }
    context.read<UserProvider>().getUsersByIds(missing).then((fetched) {
      if (mounted) setState(() => _users.addAll(fetched));
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    final requests = provider.pendingRequests;

    if (requests.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadMissingUsers(requests);
      });
    }

    if (provider.isLoading && requests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              'No pending requests',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        return _PendingRequestItem(
          request: request,
          communityId: widget.communityId,
          user: _users[request.userId],
        );
      },
    );
  }
}

class _PendingRequestItem extends StatefulWidget {
  final CommunityMemberModel request;
  final String communityId;
  final UserModel? user;

  const _PendingRequestItem({
    required this.request,
    required this.communityId,
    required this.user,
  });

  @override
  State<_PendingRequestItem> createState() => _PendingRequestItemState();
}

class _PendingRequestItemState extends State<_PendingRequestItem> {
  bool _isProcessing = false;

  Future<void> _approve() async {
    setState(() => _isProcessing = true);
    final currentUserId = context.read<UserProvider>().currentUser?.id ?? '';
    final success = await context.read<CommunityProvider>().approveRequest(
      widget.request.id, widget.communityId, currentUserId,
    );
    if (mounted) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'Request approved' : 'Failed to approve'),
        backgroundColor: success ? AppTheme.successGreen : AppTheme.primaryRed,
      ));
    }
  }

  Future<void> _reject() async {
    final provider = context.read<CommunityProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Request'),
        content: const Text('Are you sure you want to reject this request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject', style: TextStyle(color: AppTheme.primaryRed)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    final success = await provider.rejectRequest(widget.request.id);
    if (mounted) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'Request rejected' : 'Failed to reject'),
        backgroundColor: success ? AppTheme.warningOrange : AppTheme.primaryRed,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          UserAvatar(
            photoUrl: user?.profilePhotoUrl,
            initials: user?.initials ?? '?',
            radius: 22,
            backgroundColor: AppTheme.primaryDark,
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
                    fontWeight: FontWeight.w700,
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
          Text(
            widget.request.timeAgo,
            style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 12),
          if (_isProcessing)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else ...[
            OutlinedButton(
              onPressed: _reject,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryRed,
                side: const BorderSide(color: AppTheme.primaryRed),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Reject'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _approve,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Approve'),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Members Content ────────────────────────────────────────────────────────────

class _MembersContent extends StatefulWidget {
  final String communityId;

  const _MembersContent({required this.communityId});

  @override
  State<_MembersContent> createState() => _MembersContentState();
}

class _MembersContentState extends State<_MembersContent> {
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

  void _reload() {
    setState(() {
      _isLoading = true;
      _users.clear();
    });
    _loadMembers();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<UserProvider>().currentUser?.id ?? '';

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
        return _MemberItem(
          member: member,
          user: _users[member.userId],
          communityId: widget.communityId,
          currentUserId: currentUserId,
          onChanged: _reload,
        );
      },
    );
  }
}

class _MemberItem extends StatefulWidget {
  final CommunityMemberModel member;
  final UserModel? user;
  final String communityId;
  final String currentUserId;
  final VoidCallback onChanged;

  const _MemberItem({
    required this.member,
    required this.user,
    required this.communityId,
    required this.currentUserId,
    required this.onChanged,
  });

  @override
  State<_MemberItem> createState() => _MemberItemState();
}

class _MemberItemState extends State<_MemberItem> {
  bool _isProcessing = false;

  Future<void> _handleAction(String action) async {
    final provider = context.read<CommunityProvider>();

    if (action == 'remove') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Remove Member'),
          content: Text('Remove ${widget.user?.name ?? 'this member'} from the community?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
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
        case 'promote':
          success = await provider.promoteToAdmin(widget.member.id);
          successMsg = 'Promoted to admin';
          break;
        case 'demote':
          success = await provider.demoteToMember(widget.member.id, widget.communityId);
          successMsg = 'Demoted to member';
          break;
        case 'remove':
          success = await provider.removeMember(widget.communityId, widget.member.userId);
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
    final isSelf = member.userId == widget.currentUserId;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          UserAvatar(
            photoUrl: user?.profilePhotoUrl,
            initials: user?.initials ?? '?',
            radius: 20,
            backgroundColor: member.isAdmin ? AppTheme.primaryRed : AppTheme.primaryDark,
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
              color: member.isAdmin
                  ? AppTheme.primaryRed.withValues(alpha: 0.1)
                  : AppTheme.backgroundGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              member.isAdmin ? 'Admin' : 'Member',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: member.isAdmin ? AppTheme.primaryRed : AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (_isProcessing)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (isSelf)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'You',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  color: AppTheme.primaryRed,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            PopupMenuButton<String>(
              onSelected: _handleAction,
              icon: Icon(Icons.more_vert, size: 18, color: AppTheme.textSecondary),
              itemBuilder: (context) => [
                if (!member.isAdmin)
                  const PopupMenuItem(
                    value: 'promote',
                    child: Row(
                      children: [
                        Icon(Icons.arrow_upward, size: 16),
                        SizedBox(width: 8),
                        Text('Promote to Admin'),
                      ],
                    ),
                  ),
                if (member.isAdmin)
                  const PopupMenuItem(
                    value: 'demote',
                    child: Row(
                      children: [
                        Icon(Icons.arrow_downward, size: 16),
                        SizedBox(width: 8),
                        Text('Demote to Member'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(Icons.remove_circle_outline, size: 16, color: AppTheme.primaryRed),
                      SizedBox(width: 8),
                      Text('Remove', style: TextStyle(color: AppTheme.primaryRed)),
                    ],
                  ),
                ),
              ],
            ),
        ],
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
