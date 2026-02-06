import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/community_model.dart';
import '../../data/services/location_service.dart';
import '../../utils/app_theme.dart';
import '../providers/community_provider.dart';
import '../providers/user_provider.dart';
import 'create_community_screen.dart';
import 'community_detail_screen.dart';

class CommunityListScreen extends StatefulWidget {
  const CommunityListScreen({super.key});

  @override
  State<CommunityListScreen> createState() => _CommunityListScreenState();
}

class _CommunityListScreenState extends State<CommunityListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _locationService = LocationService();
  bool _loadingLocation = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final userId = context.read<UserProvider>().currentUser?.id;
    final communityProvider = context.read<CommunityProvider>();

    if (userId != null) {
      communityProvider.loadMyCommunities(userId);
    }

    setState(() => _loadingLocation = true);
    try {
      final pos = await _locationService.getCurrentPosition();
      if (pos != null && mounted) {
        await communityProvider.loadNearbyCommunities(
            pos.latitude, pos.longitude);
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingLocation = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Communities'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppTheme.primaryRed,
          tabs: const [
            Tab(text: 'My Communities'),
            Tab(text: 'Discover'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MyCommunities(onRefresh: _loadData),
          _DiscoverCommunities(
            loadingLocation: _loadingLocation,
            onRefresh: _loadData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreateCommunityScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Create'),
        backgroundColor: AppTheme.primaryRed,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _MyCommunities extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _MyCommunities({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    final communities = provider.myCommunities;

    if (provider.isLoading && communities.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (communities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No communities yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create one or join an existing community',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: communities.length,
        itemBuilder: (context, index) {
          return _CommunityCard(
            community: communities[index],
            showJoinButton: false,
          );
        },
      ),
    );
  }
}

class _DiscoverCommunities extends StatelessWidget {
  final bool loadingLocation;
  final Future<void> Function() onRefresh;

  const _DiscoverCommunities({
    required this.loadingLocation,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    final communities = provider.nearbyCommunities;
    final myCommunityIds = provider.myCommunities.map((c) => c.id).toSet();

    // Filter out communities user is already a member of
    final discoverCommunities =
        communities.where((c) => !myCommunityIds.contains(c.id)).toList();

    if (loadingLocation || (provider.isLoading && communities.isEmpty)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              loadingLocation
                  ? 'Finding nearby communities...'
                  : 'Loading...',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (discoverCommunities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.explore_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No communities nearby',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to create one!',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: discoverCommunities.length,
        itemBuilder: (context, index) {
          return _CommunityCard(
            community: discoverCommunities[index],
            showJoinButton: true,
          );
        },
      ),
    );
  }
}

class _CommunityCard extends StatelessWidget {
  final CommunityModel community;
  final bool showJoinButton;

  const _CommunityCard({
    required this.community,
    required this.showJoinButton,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.cardBorder),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CommunityDetailScreen(communityId: community.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.accentBlue,
                    backgroundImage: community.imageUrl != null
                        ? NetworkImage(community.imageUrl!)
                        : null,
                    child: community.imageUrl == null
                        ? Text(
                            community.name.isNotEmpty
                                ? community.name[0].toUpperCase()
                                : 'C',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          community.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                community.address,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: community.isPublic
                          ? AppTheme.successGreen.withValues(alpha: 0.1)
                          : AppTheme.warningOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          community.isPublic ? Icons.public : Icons.lock,
                          size: 14,
                          color: community.isPublic
                              ? AppTheme.successGreen
                              : AppTheme.warningOrange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          community.isPublic ? 'Public' : 'Private',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: community.isPublic
                                ? AppTheme.successGreen
                                : AppTheme.warningOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                community.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.people, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${community.memberCount} members',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.radar, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${community.radius} km radius',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    community.timeAgo,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
