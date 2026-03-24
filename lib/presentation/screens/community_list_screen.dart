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
          final user = context.read<UserProvider>().currentUser;
          if (user == null || user.level < 2) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'You need to reach Level 2 (Observer) to create a community.'),
                backgroundColor: AppTheme.warningOrange,
              ),
            );
            return;
          }
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

// ── My Communities Tab ───────────────────────────────────────────────────────

class _MyCommunities extends StatefulWidget {
  final Future<void> Function() onRefresh;

  const _MyCommunities({required this.onRefresh});

  @override
  State<_MyCommunities> createState() => _MyCommunitiesState();
}

class _MyCommunitiesState extends State<_MyCommunities> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    final allCommunities = provider.myCommunities;

    final communities = _searchQuery.isEmpty
        ? allCommunities
        : allCommunities
            .where((c) =>
                c.name.toLowerCase().contains(_searchQuery) ||
                c.description.toLowerCase().contains(_searchQuery))
            .toList();

    if (provider.isLoading && allCommunities.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (allCommunities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_off, size: 64, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            Text(
              'No communities yet',
              style: TextStyle(
                fontSize: 18,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create one or join an existing community',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search my communities...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.cardBorder),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: communities.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Center(
                        child: Text(
                          'No results for "$_searchQuery"',
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: communities.length,
                    itemBuilder: (context, index) {
                      return _CommunityCard(
                        community: communities[index],
                        showJoinButton: false,
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

// ── Discover Tab ─────────────────────────────────────────────────────────────

class _DiscoverCommunities extends StatefulWidget {
  final bool loadingLocation;
  final Future<void> Function() onRefresh;

  const _DiscoverCommunities({
    required this.loadingLocation,
    required this.onRefresh,
  });

  @override
  State<_DiscoverCommunities> createState() => _DiscoverCommunitiesState();
}

class _DiscoverCommunitiesState extends State<_DiscoverCommunities> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    final allNearby = provider.nearbyCommunities;

    // Exclude communities where user has any membership
    final eligible = allNearby
        .where((c) => !provider.myMembershipCommunityIds.contains(c.id))
        .toList();

    final communities = _searchQuery.isEmpty
        ? eligible
        : eligible
            .where((c) =>
                c.name.toLowerCase().contains(_searchQuery) ||
                c.description.toLowerCase().contains(_searchQuery))
            .toList();

    if (widget.loadingLocation ||
        (provider.isLoading && allNearby.isEmpty)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              widget.loadingLocation
                  ? 'Finding nearby communities...'
                  : 'Loading...',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    if (eligible.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.explore_off, size: 64, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            Text(
              'No communities nearby',
              style: TextStyle(
                fontSize: 18,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to create one!',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search communities...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.cardBorder),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: communities.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Center(
                        child: Text(
                          'No results for "$_searchQuery"',
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: communities.length,
                    itemBuilder: (context, index) {
                      final c = communities[index];
                      final lat = provider.userLat;
                      final lng = provider.userLng;
                      return _CommunityCard(
                        community: c,
                        showJoinButton: true,
                        distanceKm: (lat != null && lng != null)
                            ? c.calculateDistance(lat, lng)
                            : null,
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

// ── Community Card ────────────────────────────────────────────────────────────

class _CommunityCard extends StatelessWidget {
  final CommunityModel community;
  final bool showJoinButton;
  final double? distanceKm;

  const _CommunityCard({
    required this.community,
    required this.showJoinButton,
    this.distanceKm,
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
                    backgroundColor: AppTheme.primaryDark,
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
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                community.address,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
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
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.people, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '${community.memberCount} members',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.radar, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${community.radius} km radius',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    community.timeAgo,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              if (distanceKm != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.near_me,
                        size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '${distanceKm!.toStringAsFixed(1)} km away',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
