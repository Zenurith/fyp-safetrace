import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/incident_model.dart';
import '../../data/models/vote_model.dart';
import '../../utils/app_theme.dart';
import '../providers/vote_provider.dart';
import '../providers/user_provider.dart';

class VoteButtons extends StatelessWidget {
  final IncidentModel incident;
  final bool compact;

  const VoteButtons({
    super.key,
    required this.incident,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final voteProvider = context.watch<VoteProvider>();
    final currentUser = userProvider.currentUser;

    if (currentUser == null) {
      return const SizedBox.shrink();
    }

    final isOwnReport = currentUser.id == incident.reporterId;
    final userVote = voteProvider.getVoteForIncident(incident.id);
    final hasUpvoted = userVote?.type == VoteType.upvote;
    final hasDownvoted = userVote?.type == VoteType.downvote;

    if (compact) {
      return _buildCompactButtons(
        context,
        voteProvider,
        currentUser.id,
        isOwnReport,
        hasUpvoted,
        hasDownvoted,
      );
    }

    return _buildFullButtons(
      context,
      voteProvider,
      currentUser.id,
      isOwnReport,
      hasUpvoted,
      hasDownvoted,
    );
  }

  Widget _buildCompactButtons(
    BuildContext context,
    VoteProvider voteProvider,
    String userId,
    bool isOwnReport,
    bool hasUpvoted,
    bool hasDownvoted,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _VoteIconButton(
          icon: Icons.arrow_upward_rounded,
          count: incident.upvotes,
          isActive: hasUpvoted,
          activeColor: AppTheme.successGreen,
          isDisabled: isOwnReport,
          onPressed: isOwnReport
              ? null
              : () => _handleVote(context, voteProvider, userId, VoteType.upvote),
        ),
        const SizedBox(width: 8),
        _VoteIconButton(
          icon: Icons.arrow_downward_rounded,
          count: incident.downvotes,
          isActive: hasDownvoted,
          activeColor: AppTheme.primaryRed,
          isDisabled: isOwnReport,
          onPressed: isOwnReport
              ? null
              : () => _handleVote(context, voteProvider, userId, VoteType.downvote),
        ),
      ],
    );
  }

  Widget _buildFullButtons(
    BuildContext context,
    VoteProvider voteProvider,
    String userId,
    bool isOwnReport,
    bool hasUpvoted,
    bool hasDownvoted,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundGrey,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _VoteButton(
            icon: Icons.thumb_up_outlined,
            activeIcon: Icons.thumb_up,
            label: '${incident.upvotes}',
            isActive: hasUpvoted,
            activeColor: AppTheme.successGreen,
            isDisabled: isOwnReport,
            onPressed: isOwnReport
                ? null
                : () => _handleVote(context, voteProvider, userId, VoteType.upvote),
          ),
          Container(
            height: 24,
            width: 1,
            color: AppTheme.cardBorder,
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),
          Text(
            '${incident.voteScore}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: incident.voteScore > 0
                  ? AppTheme.successGreen
                  : incident.voteScore < 0
                      ? AppTheme.primaryRed
                      : AppTheme.primaryDark,
            ),
          ),
          Container(
            height: 24,
            width: 1,
            color: AppTheme.cardBorder,
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),
          _VoteButton(
            icon: Icons.thumb_down_outlined,
            activeIcon: Icons.thumb_down,
            label: '${incident.downvotes}',
            isActive: hasDownvoted,
            activeColor: AppTheme.primaryRed,
            isDisabled: isOwnReport,
            onPressed: isOwnReport
                ? null
                : () => _handleVote(context, voteProvider, userId, VoteType.downvote),
          ),
        ],
      ),
    );
  }

  Future<void> _handleVote(
    BuildContext context,
    VoteProvider voteProvider,
    String userId,
    VoteType type,
  ) async {
    final success = await voteProvider.vote(
      incidentId: incident.id,
      voterId: userId,
      reporterId: incident.reporterId,
      type: type,
    );

    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(voteProvider.error ?? 'Failed to register vote'),
          backgroundColor: AppTheme.primaryRed,
        ),
      );
    }
  }
}

class _VoteButton extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final bool isDisabled;
  final VoidCallback? onPressed;

  const _VoteButton({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.isDisabled,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDisabled
        ? Colors.grey.shade400
        : isActive
            ? activeColor
            : AppTheme.primaryDark;

    return InkWell(
      onTap: isDisabled ? null : onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 20,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoteIconButton extends StatelessWidget {
  final IconData icon;
  final int count;
  final bool isActive;
  final Color activeColor;
  final bool isDisabled;
  final VoidCallback? onPressed;

  const _VoteIconButton({
    required this.icon,
    required this.count,
    required this.isActive,
    required this.activeColor,
    required this.isDisabled,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDisabled
        ? Colors.grey.shade400
        : isActive
            ? activeColor
            : Colors.grey.shade600;

    return InkWell(
      onTap: isDisabled ? null : onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 2),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
