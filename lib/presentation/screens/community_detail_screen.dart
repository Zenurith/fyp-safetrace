import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/community_member_model.dart';
import '../../data/models/community_model.dart';
import '../../data/models/incident_model.dart';
import '../../utils/app_theme.dart';
import '../providers/community_provider.dart';
import '../providers/incident_provider.dart';
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
      messenger.showSnackBar(
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

    return Scaffold(
      appBar: AppBar(
        title: Text(community.name),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              tooltip: 'Admin Panel',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CommunityAdminScreen(communityId: widget.communityId),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CommunityHeader(community: community),

            Padding(
              padding: const EdgeInsets.all(16),
              child: _MembershipSection(
                membership: membership,
                isAdmin: _isAdmin,
                onRequestJoin: _requestToJoin,
                onLeave: _leaveCommunity,
              ),
            ),

            _InfoSection(community: community),

            if (isApprovedMember) ...[
              const SizedBox(height: 8),
              _CommunitySharedIncidentsSection(communityId: widget.communityId),
              const SizedBox(height: 8),
              _CommunityIncidentsSection(community: community),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
      floatingActionButton: null,
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
            value: community.timeAgo,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Community shared incidents section
// ---------------------------------------------------------------------------

class _CommunitySharedIncidentsSection extends StatelessWidget {
  final String communityId;

  const _CommunitySharedIncidentsSection({required this.communityId});

  @override
  Widget build(BuildContext context) {
    final allIncidents = context.watch<IncidentProvider>().allIncidents;
    final shared = allIncidents
        .where((i) => i.communityIds.contains(communityId))
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: 'Posts', count: shared.length),
          const SizedBox(height: 12),
          if (shared.isEmpty)
            _EmptyState(
              icon: Icons.forum_outlined,
              message: 'No posts yet. Report an incident and share it here!',
            )
          else
            ...shared.map((i) => _IncidentCard(incident: i)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Incidents section
// ---------------------------------------------------------------------------

class _CommunityIncidentsSection extends StatelessWidget {
  final CommunityModel community;

  const _CommunityIncidentsSection({required this.community});

  @override
  Widget build(BuildContext context) {
    final allIncidents = context.watch<IncidentProvider>().allIncidents;
    final nearby = allIncidents
        .where((i) => community.isLocationWithinRadius(i.latitude, i.longitude))
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: 'Nearby Incidents', count: nearby.length),
          const SizedBox(height: 12),
          if (nearby.isEmpty)
            _EmptyState(
              icon: Icons.shield_outlined,
              message: 'No incidents reported in this area',
            )
          else
            ...nearby.take(5).map((i) => _IncidentCard(incident: i)),
          if (nearby.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+ ${nearby.length - 5} more incidents in this area',
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
    final isHigh = incident.severity == SeverityLevel.high;
    final color = isHigh ? AppTheme.primaryRed : AppTheme.warningOrange;

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => IncidentBottomSheet(incidentId: incident.id),
      ),
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
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared small widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: AppTheme.headingSmall),
        const SizedBox(width: 8),
        Text('($count)', style: AppTheme.caption),
      ],
    );
  }
}

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
          Text(message, style: AppTheme.caption),
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
          Text(label, style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
          const Spacer(),
          Text(value, style: AppTheme.bodyMedium),
        ],
      ),
    );
  }
}
