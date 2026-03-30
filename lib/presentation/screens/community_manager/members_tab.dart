part of '../community_manager_screen.dart';

// ── Members Tab ───────────────────────────────────────────────────────────────

class _MembersTab extends StatefulWidget {
  final String communityId;
  final CommunityMemberModel? myMembership;

  const _MembersTab({
    super.key,
    required this.communityId,
    required this.myMembership,
  });

  @override
  State<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<_MembersTab> {
  List<CommunityMemberModel> _members = [];
  bool _isLoading = true;
  final Map<String, UserModel?> _users = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
    _loadMembers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    final provider = context.read<CommunityProvider>();
    final members = await provider.getCommunityMembers(widget.communityId);
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
    final currentUserId =
        context.watch<UserProvider>().currentUser?.id ?? '';

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_members.isEmpty) {
      return const Center(child: Text('No members found'));
    }

    final filtered = _searchQuery.isEmpty
        ? _members
        : _members.where((m) {
            final name = _users[m.userId]?.name.toLowerCase() ?? '';
            final handle = _users[m.userId]?.handle.toLowerCase() ?? '';
            return name.contains(_searchQuery) || handle.contains(_searchQuery);
          }).toList();

    return Column(
      children: [
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
          child: RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _isLoading = true;
                _users.clear();
              });
              await _loadMembers();
            },
            child: filtered.isEmpty
                ? const Center(child: Text('No members match your search'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final member = filtered[index];
                      return _MemberListItem(
                        member: member,
                        user: _users[member.userId],
                        communityId: widget.communityId,
                        currentUserId: currentUserId,
                        myMembership: widget.myMembership,
                        onChanged: _reload,
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _MemberListItem extends StatefulWidget {
  final CommunityMemberModel member;
  final UserModel? user;
  final String communityId;
  final String currentUserId;
  final CommunityMemberModel? myMembership;
  final VoidCallback onChanged;

  const _MemberListItem({
    required this.member,
    required this.user,
    required this.communityId,
    required this.currentUserId,
    required this.myMembership,
    required this.onChanged,
  });

  @override
  State<_MemberListItem> createState() => _MemberListItemState();
}

class _MemberListItemState extends State<_MemberListItem> {
  bool _isProcessing = false;

  // ── Permission helpers ────────────────────────────────────────────────────

  bool _canPromoteToMod(MemberRole? my, MemberRole target) =>
      (my == MemberRole.owner || my == MemberRole.headModerator) &&
      target == MemberRole.member;

  bool _canPromoteToHeadMod(MemberRole? my, MemberRole target) =>
      my == MemberRole.owner && target == MemberRole.moderator;

  bool _canDemoteToMod(MemberRole? my, MemberRole target) =>
      my == MemberRole.owner && target == MemberRole.headModerator;

  bool _canDemoteToMember(MemberRole? my, MemberRole target) =>
      (my == MemberRole.owner || my == MemberRole.headModerator) &&
      target == MemberRole.moderator;

  bool _canRemove(MemberRole? my, MemberRole target) {
    if (target == MemberRole.owner) return false;
    if (target == MemberRole.member) {
      return my == MemberRole.owner ||
          my == MemberRole.headModerator ||
          my == MemberRole.moderator;
    }
    if (target == MemberRole.moderator) {
      return my == MemberRole.owner || my == MemberRole.headModerator;
    }
    if (target == MemberRole.headModerator) {
      return my == MemberRole.owner;
    }
    return false;
  }

  bool _canTransfer(MemberRole? my, MemberRole target) =>
      my == MemberRole.owner && target != MemberRole.owner;

  // Ban has the same permission matrix as remove
  bool _canBan(MemberRole? my, MemberRole target) => _canRemove(my, target);

  Future<DateTime?> _pickBanDuration() async {
    const options = [
      ('1 hour', Duration(hours: 1)),
      ('1 day', Duration(days: 1)),
      ('3 days', Duration(days: 3)),
      ('7 days', Duration(days: 7)),
      ('30 days', Duration(days: 30)),
    ];
    return showDialog<DateTime>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Ban Duration'),
        children: options
            .map((opt) => SimpleDialogOption(
                  onPressed: () =>
                      Navigator.pop(ctx, DateTime.now().add(opt.$2)),
                  child: Text(opt.$1),
                ))
            .toList(),
      ),
    );
  }

  // ── Role badge color ──────────────────────────────────────────────────────

  Color _roleBadgeColor(MemberRole role) {
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

  // ── Action handler ────────────────────────────────────────────────────────

  Future<void> _handleAction(String action) async {
    // Show dialogs before entering processing state
    DateTime? tempBanUntil;

    if (action == 'temp_ban') {
      tempBanUntil = await _pickBanDuration();
      if (tempBanUntil == null) return;
    } else if (action == 'ban') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Permanently Ban'),
          content: Text(
              'Permanently ban ${widget.user?.name ?? 'this member'} from the community? They will not be able to rejoin.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ban',
                  style: TextStyle(color: AppTheme.primaryRed)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    } else if (action == 'remove') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Remove Member'),
          content: Text(
              'Remove ${widget.user?.name ?? 'this member'} from the community?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove',
                  style: TextStyle(color: AppTheme.primaryRed)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    } else if (action == 'transfer') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Transfer Ownership'),
          content: Text(
              'Transfer ownership to ${widget.user?.name ?? 'this member'}? You will become Head Moderator.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Transfer',
                  style: TextStyle(color: AppTheme.primaryRed)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (!mounted) return;
    setState(() => _isProcessing = true);

    final provider = context.read<CommunityProvider>();
    final messenger = ScaffoldMessenger.of(context);
    bool success = false;
    String successMsg = '';

    try {
      switch (action) {
        case 'promote_mod':
          success = await provider.promoteToModerator(widget.member.id);
          successMsg = 'Promoted to Moderator';
          break;
        case 'promote_headmod':
          success = await provider.promoteToHeadModerator(
              widget.communityId, widget.member.id);
          successMsg = 'Promoted to Head Moderator';
          break;
        case 'demote_mod':
          success = await provider.demoteToModerator(widget.member.id);
          successMsg = 'Demoted to Moderator';
          break;
        case 'demote_member':
          success = await provider.demoteToMember(
              widget.member.id, widget.communityId);
          successMsg = 'Demoted to Member';
          break;
        case 'temp_ban':
          success = await provider.banMember(
              widget.member.id, widget.communityId,
              bannedUntil: tempBanUntil);
          successMsg = 'Member temporarily banned';
          break;
        case 'ban':
          success = await provider.banMember(
              widget.member.id, widget.communityId);
          successMsg = 'Member permanently banned';
          break;
        case 'transfer':
          success = await provider.transferOwnership(
              widget.communityId, widget.currentUserId, widget.member.userId);
          successMsg = 'Ownership transferred';
          break;
        case 'remove':
          success = await provider.removeMember(
              widget.member.id, widget.communityId);
          successMsg = 'Member removed';
          break;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        messenger.showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppTheme.primaryRed,
        ));
      }
      return;
    }

    if (mounted) {
      setState(() => _isProcessing = false);
      if (success) {
        widget.onChanged();
        messenger.showSnackBar(SnackBar(
          content: Text(successMsg),
          backgroundColor: AppTheme.successGreen,
        ));
      } else {
        messenger.showSnackBar(SnackBar(
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
    final myRole = widget.myMembership?.role;
    final targetRole = member.role;
    final badgeColor = _roleBadgeColor(targetRole);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: UserAvatar(
        photoUrl: user?.profilePhotoUrl,
        initials: user?.initials ?? '?',
        radius: 20,
        backgroundColor:
            member.isStaff ? AppTheme.primaryRed : AppTheme.primaryDark,
      ),
      title: Text(user?.name ?? '...'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user != null)
            Text(
              user.handle,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          Text(
            member.roleLabel,
            style: TextStyle(
              fontSize: 12,
              color: badgeColor,
              fontWeight: member.isStaff ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
      trailing: _isProcessing
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : isSelf
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'You',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.primaryRed,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              : PopupMenuButton<String>(
                  onSelected: _handleAction,
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (context) => [
                    if (_canPromoteToMod(myRole, targetRole))
                      const PopupMenuItem(
                        value: 'promote_mod',
                        child: Row(children: [
                          Icon(Icons.arrow_upward, size: 16),
                          SizedBox(width: 8),
                          Text('Promote to Moderator'),
                        ]),
                      ),
                    if (_canPromoteToHeadMod(myRole, targetRole))
                      const PopupMenuItem(
                        value: 'promote_headmod',
                        child: Row(children: [
                          Icon(Icons.keyboard_double_arrow_up, size: 16),
                          SizedBox(width: 8),
                          Text('Promote to Head Mod'),
                        ]),
                      ),
                    if (_canDemoteToMod(myRole, targetRole))
                      const PopupMenuItem(
                        value: 'demote_mod',
                        child: Row(children: [
                          Icon(Icons.arrow_downward, size: 16),
                          SizedBox(width: 8),
                          Text('Demote to Moderator'),
                        ]),
                      ),
                    if (_canDemoteToMember(myRole, targetRole))
                      const PopupMenuItem(
                        value: 'demote_member',
                        child: Row(children: [
                          Icon(Icons.arrow_downward, size: 16),
                          SizedBox(width: 8),
                          Text('Demote to Member'),
                        ]),
                      ),
                    if (_canTransfer(myRole, targetRole))
                      const PopupMenuItem(
                        value: 'transfer',
                        child: Row(children: [
                          Icon(Icons.swap_horiz, size: 16),
                          SizedBox(width: 8),
                          Text('Transfer Ownership'),
                        ]),
                      ),
                    if (_canBan(myRole, targetRole)) ...[
                      const PopupMenuItem(
                        value: 'remove',
                        child: Row(children: [
                          Icon(Icons.remove_circle_outline,
                              size: 16, color: AppTheme.primaryRed),
                          SizedBox(width: 8),
                          Text('Kick',
                              style: TextStyle(color: AppTheme.primaryRed)),
                        ]),
                      ),
                      const PopupMenuItem(
                        value: 'temp_ban',
                        child: Row(children: [
                          Icon(Icons.timer_off_outlined,
                              size: 16, color: AppTheme.primaryRed),
                          SizedBox(width: 8),
                          Text('Temp Ban',
                              style: TextStyle(color: AppTheme.primaryRed)),
                        ]),
                      ),
                      const PopupMenuItem(
                        value: 'ban',
                        child: Row(children: [
                          Icon(Icons.block,
                              size: 16, color: AppTheme.primaryRed),
                          SizedBox(width: 8),
                          Text('Ban',
                              style: TextStyle(color: AppTheme.primaryRed)),
                        ]),
                      ),
                    ],
                  ],
                ),
    );
  }
}
