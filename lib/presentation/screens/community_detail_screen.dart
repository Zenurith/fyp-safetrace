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
import '../widgets/flag_dialog.dart';
import '../widgets/incident_bottom_sheet.dart';
import '../widgets/user_avatar.dart';
import '../../data/models/flag_model.dart';
import 'community_manager_screen.dart';
import 'create_community_screen.dart';
import 'create_post_screen.dart';

part 'community_detail/incidents_tab.dart';
part 'community_detail/members_list_tab.dart';
part 'community_detail/detail_widgets.dart';

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
            Tab(text: 'Reports'),
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
            if (membership != null &&
                membership.isApproved &&
                !membership.isOwner)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'report_community') {
                    FlagDialog.show(
                      context,
                      targetType: FlagTargetType.community,
                      targetId: widget.communityId,
                    );
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'report_community',
                    child: Row(
                      children: [
                        Icon(Icons.flag_outlined,
                            size: 18, color: AppTheme.warningOrange),
                        SizedBox(width: 8),
                        Text('Report Community'),
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

          // ── Reports tab (community incidents) ────────────────────────
          isApprovedMember
              ? _CommunityIncidentsTab(communityId: widget.communityId)
              : const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Join this community to see reports',
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
