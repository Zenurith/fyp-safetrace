part of '../community_detail_screen.dart';

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
