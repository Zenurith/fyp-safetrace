import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/community_member_model.dart';
import '../../data/models/incident_model.dart';
import '../../data/models/post_model.dart';
import '../../utils/app_theme.dart';
import '../providers/community_provider.dart';
import '../providers/incident_provider.dart';
import '../providers/post_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/incident_bottom_sheet.dart';
import 'community_admin_screen.dart';

class CommunityDetailScreen extends StatefulWidget {
  final String communityId;

  const CommunityDetailScreen({super.key, required this.communityId});

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadCommunity();
  }

  Future<void> _loadCommunity() async {
    final userId = context.read<UserProvider>().currentUser?.id;
    if (userId == null) return;

    final provider = context.read<CommunityProvider>();
    await provider.loadCommunityDetails(widget.communityId, userId);
    _isAdmin = await provider.isAdmin(widget.communityId, userId);

    // Start listening to posts for this community
    if (mounted) {
      context.read<PostProvider>().startListening(widget.communityId);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _requestToJoin() async {
    final userId = context.read<UserProvider>().currentUser?.id;
    if (userId == null) return;

    final provider = context.read<CommunityProvider>();
    final success = await provider.requestToJoin(widget.communityId, userId);

    if (mounted) {
      if (success) {
        // Reload community details to update membership status
        await _loadCommunity();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'You have joined the community!'
              : provider.error ?? 'Failed to join'),
          backgroundColor: success ? AppTheme.successGreen : AppTheme.primaryRed,
        ),
      );
    }
  }

  Future<void> _leaveCommunity() async {
    final userId = context.read<UserProvider>().currentUser?.id;
    if (userId == null) return;

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

    final provider = context.read<CommunityProvider>();
    final success = await provider.leaveCommunity(widget.communityId, userId);

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have left the community')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Failed to leave community'),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(community.name),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CommunityAdminScreen(communityId: widget.communityId),
                  ),
                );
              },
              tooltip: 'Admin Panel',
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
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
            ),

            // Membership Status & Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: _MembershipSection(
                membership: membership,
                isAdmin: _isAdmin,
                onRequestJoin: _requestToJoin,
                onLeave: _leaveCommunity,
              ),
            ),

            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'About',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    community.description,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Location Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Location',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
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
                          child: const Icon(
                            Icons.location_on,
                            color: AppTheme.primaryRed,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                community.address,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Coverage: ${community.radius} km radius',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Community Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _DetailRow(
                    icon: community.isPublic ? Icons.public : Icons.lock,
                    label: 'Visibility',
                    value: community.isPublic ? 'Public' : 'Private',
                  ),
                  _DetailRow(
                    icon: Icons.calendar_today,
                    label: 'Created',
                    value: community.timeAgo,
                  ),
                ],
              ),
            ),
            // Community Posts (visible to approved members)
            if (membership != null && membership.isApproved) ...[
              const SizedBox(height: 8),
              _CommunityPostsSection(
                communityId: widget.communityId,
                isAdmin: _isAdmin,
              ),
            ],

            // Nearby Incidents within community radius
            if (membership != null && membership.isApproved) ...[
              const SizedBox(height: 8),
              _CommunityIncidentsSection(community: community),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
      floatingActionButton: (membership != null && membership.isApproved)
          ? FloatingActionButton(
              backgroundColor: AppTheme.primaryRed,
              onPressed: () => _showCreatePostDialog(context),
              child: const Icon(Icons.edit, color: Colors.white),
            )
          : null,
    );
  }

  void _showCreatePostDialog(BuildContext context) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final userId = context.read<UserProvider>().currentUser?.id;
    if (userId == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('New Post', style: AppTheme.headingMedium),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: AppTheme.bodyMedium,
                decoration: InputDecoration(
                  labelText: 'Title',
                  labelStyle: AppTheme.caption,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                style: AppTheme.bodyMedium,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Content',
                  labelStyle: AppTheme.caption,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.cardBorder),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty ||
                  contentController.text.trim().isEmpty) return;
              final postProvider = context.read<PostProvider>();
              await postProvider.createPost(
                authorId: userId,
                communityId: widget.communityId,
                title: titleController.text.trim(),
                content: contentController.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }
}

class _CommunityPostsSection extends StatelessWidget {
  final String communityId;
  final bool isAdmin;

  const _CommunityPostsSection({
    required this.communityId,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final postProvider = context.watch<PostProvider>();
    final posts = postProvider.communityPosts;
    final currentUserId = context.read<UserProvider>().currentUser?.id;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Posts',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Text(
                '(${posts.length})',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (posts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(Icons.forum_outlined, size: 40, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'No posts yet. Be the first to share!',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          else
            ...posts.map((post) => _PostCard(
                  post: post,
                  canDelete: isAdmin || post.authorId == currentUserId,
                )),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final PostModel post;
  final bool canDelete;

  const _PostCard({required this.post, required this.canDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  post.title,
                  style: AppTheme.headingSmall,
                ),
              ),
              Text(
                post.timeAgo,
                style: AppTheme.caption,
              ),
              if (canDelete) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Post'),
                        content: const Text('Are you sure?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              context.read<PostProvider>().deletePost(post.id);
                              Navigator.pop(ctx);
                            },
                            child: const Text('Delete',
                                style: TextStyle(color: AppTheme.primaryRed)),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Icon(Icons.delete_outline, size: 18, color: Colors.grey[400]),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            post.content,
            style: AppTheme.bodyMedium.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _CommunityIncidentsSection extends StatelessWidget {
  final dynamic community; // CommunityModel

  const _CommunityIncidentsSection({required this.community});

  @override
  Widget build(BuildContext context) {
    final allIncidents = context.watch<IncidentProvider>().allIncidents;
    final nearbyIncidents = allIncidents.where((incident) {
      return community.isLocationWithinRadius(
          incident.latitude, incident.longitude);
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Nearby Incidents',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Text(
                '(${nearbyIncidents.length})',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (nearbyIncidents.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(Icons.shield_outlined, size: 40, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'No incidents reported in this area',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          else
            ...nearbyIncidents.take(5).map((incident) => _IncidentCard(
                  incident: incident,
                )),
          if (nearbyIncidents.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+ ${nearbyIncidents.length - 5} more incidents in this area',
                style: AppTheme.caption,
              ),
            ),
        ],
      ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  final IncidentModel incident;

  const _IncidentCard({required this.incident});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => IncidentBottomSheet(incidentId: incident.id),
        );
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: AppTheme.cardDecoration,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: incident.severity == SeverityLevel.high
                    ? AppTheme.primaryRed.withValues(alpha: 0.1)
                    : AppTheme.warningOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                size: 20,
                color: incident.severity == SeverityLevel.high
                    ? AppTheme.primaryRed
                    : AppTheme.warningOrange,
              ),
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
          ],
        ),
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
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _MembershipSection extends StatelessWidget {
  final CommunityMemberModel? membership;
  final bool isAdmin;
  final VoidCallback onRequestJoin;
  final VoidCallback onLeave;

  const _MembershipSection({
    required this.membership,
    required this.isAdmin,
    required this.onRequestJoin,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    if (membership == null) {
      // Not a member
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.accentBlue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            const Icon(Icons.group_add, size: 32, color: AppTheme.accentBlue),
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
                  backgroundColor: AppTheme.primaryRed,
                ),
                child: const Text('Join Community'),
              ),
            ),
          ],
        ),
      );
    }

    if (membership!.isPending) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.warningOrange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppTheme.warningOrange.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.hourglass_empty, color: AppTheme.warningOrange),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Request Pending',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.warningOrange,
                    ),
                  ),
                  Text(
                    'Waiting for admin approval',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (membership!.isRejected) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.primaryRed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.block, color: AppTheme.primaryRed),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Request Rejected',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryRed,
                    ),
                  ),
                  Text(
                    'Your request was not approved',
                    style: TextStyle(fontSize: 12),
                  ),
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

    // Approved member
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.successGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isAdmin ? Icons.admin_panel_settings : Icons.verified_user,
            color: AppTheme.successGreen,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAdmin ? 'Admin' : 'Member',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.successGreen,
                  ),
                ),
                Text(
                  'Joined ${membership!.timeAgo}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onLeave,
            child: const Text(
              'Leave',
              style: TextStyle(color: AppTheme.primaryRed),
            ),
          ),
        ],
      ),
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
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
