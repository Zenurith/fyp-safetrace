import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/community_member_model.dart';
import '../../data/models/flag_model.dart';
import '../../data/models/incident_model.dart';
import '../../data/models/user_model.dart';
import '../../utils/app_theme.dart';
import '../../data/repositories/community_repository.dart';
import '../providers/comment_provider.dart';
import '../providers/community_provider.dart';
import '../providers/flag_provider.dart';
import '../providers/incident_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/incident_bottom_sheet.dart';
import '../widgets/user_avatar.dart';
import 'create_community_screen.dart';

part 'community_manager/pending_incidents_tab.dart';
part 'community_manager/pending_requests_tab.dart';
part 'community_manager/members_tab.dart';
part 'community_manager/flags_tab.dart';

class CommunityManagerScreen extends StatefulWidget {
  final String communityId;

  const CommunityManagerScreen({super.key, required this.communityId});

  @override
  State<CommunityManagerScreen> createState() => _CommunityManagerScreenState();
}

class _CommunityManagerScreenState extends State<CommunityManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final FlagProvider _flagProvider;
  late final IncidentProvider _incidentProvider;
  late final CommunityProvider _communityProvider;
  // Incrementing this causes _MembersTab to rebuild with a new Key, resetting
  // its state and triggering a fresh member list load.
  int _membersReloadKey = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _flagProvider = context.read<FlagProvider>();
    _incidentProvider = context.read<IncidentProvider>();
    _communityProvider = context.read<CommunityProvider>();
    // Refresh Reports from server whenever the user switches to that tab
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _communityProvider.watchPendingRequests(widget.communityId);
      _flagProvider.startListeningFlagsByCommunity(widget.communityId);
      _incidentProvider.watchPendingCommunityIncidents(widget.communityId);
      _incidentProvider.watchCommunityIncidents(widget.communityId);
      if (mounted) setState(() => _membersReloadKey++);
    });
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    // Force a server-side refresh when switching to Incidents (1) or
    // Reports (3) so stale cache / missed push-updates from another device
    // are immediately corrected.
    switch (_tabController.index) {
      case 1:
        _incidentProvider.refreshCommunityIncidents();
        break;
      case 3:
        _flagProvider.refreshCommunityFlags();
        break;
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _flagProvider.stopListeningCommunityFlags();
    _communityProvider.stopWatchingPendingRequests();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myMembership =
        context.watch<CommunityProvider>().currentMembership;
    final canEdit = myMembership?.isOwner == true ||
        myMembership?.isHeadModerator == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Community'),
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Community',
              onPressed: () {
                final community =
                    context.read<CommunityProvider>().selectedCommunity;
                if (community != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CreateCommunityScreen(communityToEdit: community),
                    ),
                  );
                }
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppTheme.primaryRed,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Requests'),
                  if (context.watch<CommunityProvider>().pendingRequests.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryRed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${context.watch<CommunityProvider>().pendingRequests.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
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
                  const Text('Incidents'),
                  if (context.watch<IncidentProvider>().pendingCommunityIncidents.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryRed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${context.watch<IncidentProvider>().pendingCommunityIncidents.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Members'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Reports'),
                  if (context.watch<FlagProvider>().communityPendingCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryRed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${context.watch<FlagProvider>().communityPendingCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PendingRequestsTab(
            communityId: widget.communityId,
          ),
            _AllIncidentsTab(communityId: widget.communityId),
          _MembersTab(
            key: ValueKey(_membersReloadKey),
            communityId: widget.communityId,
            myMembership: myMembership,
          ),
          _CommunityFlagsTab(communityId: widget.communityId),
        ],
      ),
    );
  }
}
