import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/community_member_model.dart';
import '../../data/models/community_model.dart';
import '../../data/models/incident_model.dart';
import '../../data/models/user_model.dart';
import '../../utils/app_theme.dart';
import '../providers/community_provider.dart';
import '../providers/incident_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/incident_bottom_sheet.dart';
import '../widgets/user_avatar.dart';
import 'community_manager_screen.dart';
import 'create_community_screen.dart';

class CommunityDetailScreen extends StatefulWidget {
  final String communityId;

  const CommunityDetailScreen({super.key, required this.communityId});

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCommunity();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCommunity() async {
    if (mounted) setState(() => _isLoading = true);

    final userId = context.read<UserProvider>().currentUser?.id;
    if (userId == null) return;

    final provider = context.read<CommunityProvider>();
    await provider.loadCommunityDetails(widget.communityId, userId);
    final m = provider.currentMembership;

    if (m?.isStaff == true && m?.isApproved == true) {
      await provider.loadPendingRequests(widget.communityId);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _requestToJoin() async {
    final userId = context.read<UserProvider>().currentUser?.id;
    if (userId == null) return;

    final provider = context.read<CommunityProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final success = await provider.requestToJoin(widget.communityId, userId);

    if (mounted) {
      if (success) await _loadCommunity();
      final isPending = provider.currentMembership?.isPending ?? false;
      messenger.showSnackBar(
        SnackBar(
          content: Text(success
              ? (isPending
                  ? 'Join request sent! Waiting for admin approval.'
                  : 'You have joined the community!')
              : provider.error ?? 'Failed to join'),
          backgroundColor: success ? AppTheme.successGreen : AppTheme.primaryRed,
        ),
      );
    }
  }

  Future<void> _leaveCommunity() async {
    final userId = context.read<UserProvider>().currentUser?.id;
    if (userId == null) return;

    final provider = context.read<CommunityProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Community'),
        content: const Text('Are you sure you want to leave this community?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave',
                style: TextStyle(color: AppTheme.primaryRed)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await provider.leaveCommunity(widget.communityId, userId);

    if (mounted) {
      if (success) {
        navigator.pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('You have left the community')),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Failed to leave community'),
            backgroundColor: AppTheme.primaryRed,
          ),
        );
      }
    }
  }

  Future<void> _deleteCommunity() async {
    final community = context.read<CommunityProvider>().selectedCommunity;
    if (community == null) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Community'),
        content: Text(
            'Are you sure you want to permanently delete "${community.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.primaryRed)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await context
        .read<CommunityProvider>()
        .deleteCommunity(widget.communityId);

    if (mounted) {
      if (success) {
        navigator.pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('Community deleted')),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.read<CommunityProvider>().error ??
                'Failed to delete community'),
            backgroundColor: AppTheme.primaryRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    final community = provider.selectedCommunity;
    final membership = provider.currentMembership;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Community')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (community == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Community')),
        body: const Center(child: Text('Community not found')),
      );
    }

    final isApprovedMember = membership != null && membership.isApproved;
    final isStaff =
        membership?.isStaff == true && membership?.isApproved == true;
    final canEdit = membership?.isApproved == true &&
        (membership?.isOwner == true || membership?.isHeadModerator == true);
    final canDelete =
        membership?.isOwner == true && membership?.isApproved == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(community.name),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppTheme.primaryRed,
          tabs: const [
            Tab(text: 'About'),
            Tab(text: 'Posts'),
            Tab(text: 'Members'),
          ],
        ),
        actions: [
          if (isStaff) ...[
            if (canEdit)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit Community',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CreateCommunityScreen(communityToEdit: community),
                  ),
                ).then((_) => _loadCommunity()),
              ),
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.admin_panel_settings),
                  tooltip: 'Manage Community',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CommunityManagerScreen(communityId: widget.communityId),
                    ),
                  ).then((_) => _loadCommunity()),
                ),
                if (provider.pendingRequests.isNotEmpty)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryRed,
                        shape: BoxShape.circle,
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '${provider.pendingRequests.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            if (canDelete)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') _deleteCommunity();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline,
                            size: 18, color: AppTheme.primaryRed),
                        SizedBox(width: 8),
                        Text('Delete Community',
                            style: TextStyle(color: AppTheme.primaryRed)),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── About tab ──────────────────────────────────────────────────
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CommunityHeader(community: community),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _MembershipSection(
                    membership: membership,
                    onRequestJoin: _requestToJoin,
                    onLeave: _leaveCommunity,
                  ),
                ),
                _InfoSection(community: community),
                const SizedBox(height: 32),
              ],
            ),
          ),

          // ── Posts tab (incidents shared to this community) ─────────────
          isApprovedMember
              ? _SharedPostsTab(communityId: widget.communityId, isStaff: isStaff)
              : const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Join this community to see posts',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

          // ── Members tab ────────────────────────────────────────────────
          isApprovedMember
              ? _MembersListTab(
                  communityId: widget.communityId,
                  isStaff: isStaff,
                )
              : const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Join this community to see members',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

// ── Posts Tab (incidents shared to this community) ────────────────────────────

class _SharedPostsTab extends StatelessWidget {
  final String communityId;
  final bool isStaff;

  const _SharedPostsTab({required this.communityId, required this.isStaff});

  @override
  Widget build(BuildContext context) {
    final shared = context
        .watch<IncidentProvider>()
        .allIncidents
        .where((i) => i.communityIds.contains(communityId))
        .toList();

    if (shared.isEmpty) {
      return Center(
        child: _EmptyState(
          icon: Icons.share_outlined,
          message:
              'No incidents shared here yet.\nReport an incident and share it to this community.',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: shared.length,
      itemBuilder: (_, i) => _IncidentCard(
        incident: shared[i],
        communityId: communityId,
        isStaff: isStaff,
      ),
    );
  }
}

// ── Members Tab ───────────────────────────────────────────────────────────────

class _MembersListTab extends StatefulWidget {
  final String communityId;
  final bool isStaff;

  const _MembersListTab({
    required this.communityId,
    required this.isStaff,
  });

  @override
  State<_MembersListTab> createState() => _MembersListTabState();
}

class _MembersListTabState extends State<_MembersListTab> {
  List<CommunityMemberModel> _members = [];
  final Map<String, UserModel?> _users = {};
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(
        () => setState(() => _searchQuery = _searchController.text.toLowerCase()));
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final provider = context.read<CommunityProvider>();
    final members = await provider.getCommunityMembers(widget.communityId);
    if (!mounted) return;

    members.sort((a, b) => a.role.index.compareTo(b.role.index));

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

  Color _roleColor(MemberRole role) {
    switch (role) {
      case MemberRole.owner:
        return AppTheme.primaryRed;
      case MemberRole.headModerator:
        return AppTheme.warningOrange;
      case MemberRole.moderator:
        return AppTheme.successGreen;
      case MemberRole.member:
        return AppTheme.textSecondary;
    }
  }

  String _joinedAgo(CommunityMemberModel member) {
    final date = member.approvedAt ?? member.requestedAt;
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 365) return 'Joined ${(diff.inDays / 365).floor()}y ago';
    if (diff.inDays >= 30) return 'Joined ${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays >= 1) return 'Joined ${diff.inDays}d ago';
    if (diff.inHours >= 1) return 'Joined ${diff.inHours}h ago';
    return 'Joined just now';
  }

  void _showMemberProfile(
      BuildContext context, CommunityMemberModel member, UserModel? user) {
    final roleColor = _roleColor(member.role);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            UserAvatar(
              photoUrl: user?.profilePhotoUrl,
              initials: user?.initials ?? '?',
              radius: 32,
              backgroundColor:
                  member.isStaff ? AppTheme.primaryRed : AppTheme.primaryDark,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(user?.name ?? '...', style: AppTheme.headingSmall),
                if (user?.isTrusted == true) ...[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Trusted Member',
                    child: Icon(Icons.verified_rounded,
                        size: 16, color: AppTheme.successGreen),
                  ),
                ],
              ],
            ),
            if (user != null) ...[
              const SizedBox(height: 2),
              Text(user.handle, style: AppTheme.caption),
            ],
            const SizedBox(height: 12),
            // Role badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: roleColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    member.isOwner
                        ? Icons.star_rounded
                        : member.isStaff
                            ? Icons.shield_outlined
                            : Icons.person_outline,
                    size: 13,
                    color: roleColor,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    member.roleLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: roleColor,
                      fontWeight: FontWeight.w600,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Stats row
            if (user != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ProfileStat(
                    icon: Icons.emoji_events_outlined,
                    label: 'Lv.${user.level}',
                    sublabel: user.levelTitle,
                    color: AppTheme.successGreen,
                  ),
                  const SizedBox(width: 32),
                  _ProfileStat(
                    icon: Icons.stars_rounded,
                    label: '${user.points}',
                    sublabel: 'Points',
                    color: const Color(0xFFFFB800),
                  ),
                  const SizedBox(width: 32),
                  _ProfileStat(
                    icon: Icons.description_outlined,
                    label: '${user.reports}',
                    sublabel: 'Reports',
                    color: AppTheme.primaryDark,
                  ),
                ],
              ),
            const SizedBox(height: 16),
            Text(_joinedAgo(member), style: AppTheme.caption),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_members.isEmpty) {
      return Center(
        child: _EmptyState(
          icon: Icons.people_outline,
          message: 'No members found',
        ),
      );
    }

    final currentUserId =
        context.read<UserProvider>().currentUser?.id ?? '';

    final filtered = _searchQuery.isEmpty
        ? _members
        : _members.where((m) {
            final name = _users[m.userId]?.name.toLowerCase() ?? '';
            final handle = _users[m.userId]?.handle.toLowerCase() ?? '';
            return name.contains(_searchQuery) ||
                handle.contains(_searchQuery);
          }).toList();

    final staff = filtered.where((m) => m.isStaff).toList();
    final regular = filtered.where((m) => !m.isStaff).toList();

    Widget buildCard(CommunityMemberModel member) {
      final user = _users[member.userId];
      final isSelf = member.userId == currentUserId;
      final roleColor = _roleColor(member.role);

      return GestureDetector(
        onTap: () => _showMemberProfile(context, member, user),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: AppTheme.cardDecoration,
          child: Row(
            children: [
              UserAvatar(
                photoUrl: user?.profilePhotoUrl,
                initials: user?.initials ?? '?',
                radius: 20,
                backgroundColor:
                    member.isStaff ? AppTheme.primaryRed : AppTheme.primaryDark,
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
                            user?.name ?? '...',
                            style: AppTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (user?.isTrusted == true) ...[
                          const SizedBox(width: 4),
                          Tooltip(
                            message: 'Trusted Member',
                            child: Icon(Icons.verified_rounded,
                                size: 14, color: AppTheme.successGreen),
                          ),
                        ],
                        if (isSelf) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryRed.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'You',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.primaryRed,
                                fontWeight: FontWeight.w600,
                                fontFamily: AppTheme.fontFamily,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (user != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        '${user.handle}  ·  Lv.${user.level} ${user.levelTitle}',
                        style: AppTheme.caption,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      _joinedAgo(member),
                      style: AppTheme.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (member.isStaff)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: roleColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        member.isOwner
                            ? Icons.star_rounded
                            : Icons.shield_outlined,
                        size: 12,
                        color: roleColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        member.roleLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: roleColor,
                          fontWeight: FontWeight.w600,
                          fontFamily: AppTheme.fontFamily,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Icon(Icons.chevron_right, size: 18, color: AppTheme.textSecondary),
            ],
          ),
        ),
      );
    }

    Widget buildSectionHeader(String title, int count) {
      return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Row(
          children: [
            Text(
              title,
              style: AppTheme.caption.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppTheme.backgroundGrey,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$count', style: AppTheme.caption),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name or @handle...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryRed),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              // Header row: total count + manage shortcut for staff
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_members.length} ${_members.length == 1 ? 'Member' : 'Members'}',
                    style: AppTheme.headingSmall,
                  ),
                  if (widget.isStaff)
                    TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CommunityManagerScreen(
                              communityId: widget.communityId),
                        ),
                      ),
                      icon: const Icon(Icons.manage_accounts_outlined, size: 16),
                      label: const Text('Manage'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryRed,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        textStyle: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: Center(child: Text('No members match your search')),
                )
              else ...[
                if (staff.isNotEmpty) ...[
                  buildSectionHeader('STAFF', staff.length),
                  ...staff.map((m) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: buildCard(m),
                      )),
                  const SizedBox(height: 8),
                ],
                if (regular.isNotEmpty) ...[
                  buildSectionHeader('MEMBERS', regular.length),
                  ...regular.map((m) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: buildCard(m),
                      )),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;

  const _ProfileStat({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppTheme.primaryDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(sublabel, style: AppTheme.caption),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _CommunityHeader extends StatelessWidget {
  final CommunityModel community;

  const _CommunityHeader({required this.community});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryDark,
            AppTheme.primaryDark.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white,
            backgroundImage: community.imageUrl != null
                ? NetworkImage(community.imageUrl!)
                : null,
            child: community.imageUrl == null
                ? Text(
                    community.name.isNotEmpty
                        ? community.name[0].toUpperCase()
                        : 'C',
                    style: const TextStyle(
                      color: AppTheme.primaryDark,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            community.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatBadge(
                icon: Icons.people,
                label: '${community.memberCount} members',
              ),
              const SizedBox(width: 16),
              _StatBadge(
                icon: Icons.radar,
                label: '${community.radius} km',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// About / Location / Details sections
// ---------------------------------------------------------------------------

class _InfoSection extends StatelessWidget {
  final CommunityModel community;

  const _InfoSection({required this.community});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text('About', style: AppTheme.headingSmall),
          const SizedBox(height: 8),
          Text(
            community.description,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          Text('Location', style: AppTheme.headingSmall),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.backgroundGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryRed.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_on, color: AppTheme.primaryRed),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(community.address, style: AppTheme.bodyMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Coverage: ${community.radius} km radius',
                        style: AppTheme.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text('Details', style: AppTheme.headingSmall),
          const SizedBox(height: 8),
          _DetailRow(
            icon: community.isPublic ? Icons.public : Icons.lock,
            label: 'Visibility',
            value: community.isPublic ? 'Public' : 'Private',
          ),
          _DetailRow(
            icon: Icons.calendar_today,
            label: 'Created',
            value: community.createdFormatted,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Incident card
// ---------------------------------------------------------------------------

class _IncidentCard extends StatefulWidget {
  final IncidentModel incident;
  final String? communityId;
  final bool isStaff;

  const _IncidentCard({
    required this.incident,
    this.communityId,
    this.isStaff = false,
  });

  @override
  State<_IncidentCard> createState() => _IncidentCardState();
}

class _IncidentCardState extends State<_IncidentCard> {
  Future<void> _deleteIncident() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Incident'),
        content: Text(
            'Permanently delete "${widget.incident.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.primaryRed)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await context.read<IncidentProvider>().deleteIncident(widget.incident.id);
  }

  @override
  Widget build(BuildContext context) {
    final incident = widget.incident;
    final isHigh = incident.severity == SeverityLevel.high;
    final color = isHigh ? AppTheme.primaryRed : AppTheme.warningOrange;

    final cardContent = Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.warning_amber_rounded, size: 20, color: color),
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
                  '${incident.categoryLabel}  •  ${incident.severityLabel}  •  ${incident.timeAgo}',
                  style: AppTheme.caption,
                ),
              ],
            ),
          ),
          if (widget.isStaff)
            PopupMenuButton<String>(
              onSelected: (action) {
                if (action == 'delete') _deleteIncident();
              },
              icon: Icon(Icons.more_vert, size: 18, color: AppTheme.textSecondary),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline,
                          size: 16, color: AppTheme.primaryRed),
                      SizedBox(width: 8),
                      Text('Delete incident',
                          style: TextStyle(color: AppTheme.primaryRed)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => IncidentBottomSheet(incidentId: incident.id),
      ),
      child: cardContent,
    );
  }
}

// ---------------------------------------------------------------------------
// Shared small widgets
// ---------------------------------------------------------------------------


class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.backgroundGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppTheme.textSecondary),
          const SizedBox(height: 8),
          Text(message, style: AppTheme.caption, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }
}

class _MembershipSection extends StatelessWidget {
  final CommunityMemberModel? membership;
  final VoidCallback onRequestJoin;
  final VoidCallback onLeave;

  const _MembershipSection({
    required this.membership,
    required this.onRequestJoin,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    if (membership == null) {
      return _statusCard(
        color: AppTheme.primaryDark,
        child: Column(
          children: [
            const Icon(Icons.group_add, size: 32, color: AppTheme.primaryDark),
            const SizedBox(height: 8),
            const Text(
              'Join this community to connect with members and see private posts',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onRequestJoin,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryRed),
                child: const Text('Join Community'),
              ),
            ),
          ],
        ),
      );
    }

    if (membership!.isPending) {
      return _statusCard(
        color: AppTheme.warningOrange,
        child: const Row(
          children: [
            Icon(Icons.hourglass_empty, color: AppTheme.warningOrange),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Request Pending',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.warningOrange)),
                  Text('Waiting for admin approval',
                      style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (membership!.isBanned) {
      final until = membership!.bannedUntil;
      final subtitle = until != null
          ? 'Banned until ${until.day}/${until.month}/${until.year}'
          : 'You are permanently banned from this community';
      return _statusCard(
        color: AppTheme.primaryRed,
        child: Row(
          children: [
            const Icon(Icons.block, color: AppTheme.primaryRed),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Banned',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryRed)),
                  Text(subtitle, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (membership!.isRejected) {
      return _statusCard(
        color: AppTheme.primaryRed,
        child: Row(
          children: [
            const Icon(Icons.block, color: AppTheme.primaryRed),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Request Rejected',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryRed)),
                  Text('Your request was not approved',
                      style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            TextButton(
              onPressed: onRequestJoin,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    // Approved
    return _statusCard(
      color: AppTheme.successGreen,
      child: Row(
        children: [
          Icon(
            membership!.isStaff
                ? Icons.admin_panel_settings
                : Icons.verified_user,
            color: AppTheme.successGreen,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  membership!.roleLabel,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.successGreen),
                ),
                Text('Joined ${membership!.timeAgo}',
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            onPressed: onLeave,
            child: const Text('Leave',
                style: TextStyle(color: AppTheme.primaryRed)),
          ),
        ],
      ),
    );
  }

  Widget _statusCard({required Color color, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: child,
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Text(label,
              style:
                  AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
          const Spacer(),
          Text(value, style: AppTheme.bodyMedium),
        ],
      ),
    );
  }
}
