import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/post_model.dart';
import '../../data/models/vote_model.dart';
import '../../utils/app_theme.dart';
import '../providers/vote_provider.dart';
import '../providers/user_provider.dart';

class PostVoteButtons extends StatelessWidget {
  final PostModel post;

  const PostVoteButtons({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<UserProvider>().currentUser;
    final voteProvider = context.watch<VoteProvider>();

    if (currentUser == null || !currentUser.canAccessApp) {
      return const SizedBox.shrink();
    }

    final isOwnPost = currentUser.id == post.authorId;
    final userVote = voteProvider.getVoteForPost(post.id);
    final hasUpvoted = userVote?.type == VoteType.upvote;
    final hasDownvoted = userVote?.type == VoteType.downvote;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PostVoteButton(
          icon: Icons.thumb_up_outlined,
          activeIcon: Icons.thumb_up,
          count: post.upvotes,
          isActive: hasUpvoted,
          activeColor: AppTheme.successGreen,
          isDisabled: isOwnPost,
          onPressed: isOwnPost
              ? null
              : () => _handleVote(context, voteProvider, currentUser.id, VoteType.upvote),
        ),
        const SizedBox(width: 4),
        Text(
          '${post.voteScore}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: post.voteScore > 0
                ? AppTheme.successGreen
                : post.voteScore < 0
                    ? AppTheme.primaryRed
                    : AppTheme.textSecondary,
          ),
        ),
        const SizedBox(width: 4),
        _PostVoteButton(
          icon: Icons.thumb_down_outlined,
          activeIcon: Icons.thumb_down,
          count: post.downvotes,
          isActive: hasDownvoted,
          activeColor: AppTheme.primaryRed,
          isDisabled: isOwnPost,
          onPressed: isOwnPost
              ? null
              : () => _handleVote(context, voteProvider, currentUser.id, VoteType.downvote),
        ),
      ],
    );
  }

  Future<void> _handleVote(
    BuildContext context,
    VoteProvider voteProvider,
    String userId,
    VoteType type,
  ) async {
    final success = await voteProvider.voteOnPost(
      postId: post.id,
      voterId: userId,
      authorId: post.authorId,
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

class _PostVoteButton extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final int count;
  final bool isActive;
  final Color activeColor;
  final bool isDisabled;
  final VoidCallback? onPressed;

  const _PostVoteButton({
    required this.icon,
    required this.activeIcon,
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
            : AppTheme.textSecondary;

    return InkWell(
      onTap: isDisabled ? null : onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? activeIcon : icon, size: 18, color: color),
            const SizedBox(width: 3),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 13,
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
