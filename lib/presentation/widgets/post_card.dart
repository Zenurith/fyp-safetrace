import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/post_model.dart';
import '../../data/models/user_model.dart';
import '../../utils/app_theme.dart';
import '../providers/user_provider.dart';
import 'post_vote_buttons.dart';
import 'user_avatar.dart';

class PostCard extends StatelessWidget {
  final PostModel post;
  final UserModel? author;
  final bool isStaff;
  final VoidCallback? onDelete;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const PostCard({
    super.key,
    required this.post,
    required this.author,
    this.isStaff = false,
    this.onDelete,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.watch<UserProvider>().currentUser?.id;
    final canDelete = currentUserId == post.authorId || isStaff;
    final isOwnPost = currentUserId == post.authorId;

    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              UserAvatar(
                photoUrl: author?.profilePhotoUrl,
                initials: author?.initials ?? '?',
                radius: 16,
                backgroundColor: AppTheme.primaryDark,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author?.name ?? '...',
                      style: AppTheme.bodyMedium
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    Row(
                      children: [
                        Text(post.timeAgo, style: AppTheme.caption),
                        if (post.isPending) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.warningOrange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: AppTheme.warningOrange
                                      .withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              'Pending review',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.warningOrange,
                                fontWeight: FontWeight.w600,
                                fontFamily: AppTheme.fontFamily,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (post.isPrivate)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Members only',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
                ),
              if (canDelete)
                GestureDetector(
                  onTap: () => _showOptions(context, isOwnPost: isOwnPost),
                  child: const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.more_vert,
                        size: 18, color: AppTheme.textSecondary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(post.title, style: AppTheme.headingSmall),
          if (post.content.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              post.content,
              style: AppTheme.bodyMedium
                  .copyWith(color: AppTheme.textSecondary),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          // Staff inline approve/reject for pending posts
          if (isStaff && post.isPending && (onApprove != null || onReject != null)) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (onApprove != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Approve'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.successGreen,
                        side: BorderSide(
                            color: AppTheme.successGreen.withValues(alpha: 0.6)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        textStyle: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                if (onApprove != null && onReject != null)
                  const SizedBox(width: 8),
                if (onReject != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryRed,
                        side: BorderSide(
                            color: AppTheme.primaryRed.withValues(alpha: 0.6)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        textStyle: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (post.isApproved) ...[
            const SizedBox(height: 12),
            PostVoteButtons(post: post),
          ],
        ],
      ),
    );
  }

  void _showOptions(BuildContext context, {required bool isOwnPost}) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isStaff && post.isPending) ...[
              if (onApprove != null)
                ListTile(
                  leading: const Icon(Icons.check_circle_outline,
                      color: AppTheme.successGreen),
                  title: const Text('Approve post',
                      style: TextStyle(color: AppTheme.successGreen)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onApprove?.call();
                  },
                ),
              if (onReject != null)
                ListTile(
                  leading: const Icon(Icons.cancel_outlined,
                      color: AppTheme.warningOrange),
                  title: const Text('Reject post',
                      style: TextStyle(color: AppTheme.warningOrange)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onReject?.call();
                  },
                ),
            ],
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppTheme.primaryRed),
              title: const Text('Delete post',
                  style: TextStyle(color: AppTheme.primaryRed)),
              onTap: () {
                Navigator.pop(ctx);
                onDelete?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}
