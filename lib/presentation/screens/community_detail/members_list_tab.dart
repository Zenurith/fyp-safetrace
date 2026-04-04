part of '../community_detail_screen.dart';

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

class _MembersListTabState extends State<_MembersListTab>
    with AutomaticKeepAliveClientMixin {
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
      final fetched = await context.read<UserProvider>().getUsersByIds(ids);
      if (!mounted) return;
      setState(() => _users.addAll(fetched));
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
    final currentUserId =
        context.read<UserProvider>().currentUser?.id ?? '';
    final isSelf = member.userId == currentUserId;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => Padding(
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
                    color: AppTheme.reputationGold,
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
            if (!isSelf) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(sheetCtx);
                  FlagDialog.show(
                    context,
                    targetType: FlagTargetType.user,
                    targetId: member.userId,
                    communityId: widget.communityId,
                  );
                },
                icon: const Icon(Icons.flag_outlined, size: 16),
                label: const Text('Report User'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryRed,
                  textStyle: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) {
      return const _MembersShimmerList();
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

// ── Shimmer Skeleton ──────────────────────────────────────────────────────────

class _MembersShimmerList extends StatefulWidget {
  const _MembersShimmerList();

  @override
  State<_MembersShimmerList> createState() => _MembersShimmerListState();
}

class _MembersShimmerListState extends State<_MembersShimmerList>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, _) {
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 6,
          itemBuilder: (context, index) => Opacity(
            opacity: _opacity.value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: AppTheme.cardDecoration,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundGrey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 14,
                          width: 120,
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundGrey,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 11,
                          width: 80,
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundGrey,
                            borderRadius: BorderRadius.circular(4),
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
      },
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
