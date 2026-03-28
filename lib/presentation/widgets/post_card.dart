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

  const PostCard({
    super.key,
    required this.post,
    required this.author,
    this.isStaff = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.watch<UserProvider>().currentUser?.id;
    final canDelete = currentUserId == post.authorId || isStaff;

    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    Text(post.timeAgo, style: AppTheme.caption),
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
                  onTap: () => _showOptions(context),
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
          const SizedBox(height: 12),
          PostVoteButtons(post: post),
        ],
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: AppTheme.primaryRed),
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
