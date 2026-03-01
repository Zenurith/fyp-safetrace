import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/comment_model.dart';
import '../../utils/app_theme.dart';
import '../providers/comment_provider.dart';
import '../providers/user_provider.dart';
import 'user_avatar.dart';

class CommentsSection extends StatefulWidget {
  final String incidentId;

  const CommentsSection({super.key, required this.incidentId});

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  final _commentController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CommentProvider>().startListening(widget.incidentId);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final user = context.read<UserProvider>().currentUser;
    if (user == null) return;

    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    final success = await context.read<CommentProvider>().addComment(
          incidentId: widget.incidentId,
          authorId: user.id,
          authorName: user.name,
          authorPhotoUrl: user.profilePhotoUrl,
          content: content,
        );

    if (success && mounted) {
      _commentController.clear();
      _focusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<CommentProvider>(
      builder: (context, provider, _) {
        final comments = provider.getComments(widget.incidentId);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.comment_outlined,
                      size: 18,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Comments',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.primaryDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${comments.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryRed,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    ),
                  ],
                ),
              ),
            ),

            // Expanded content
            if (_isExpanded) ...[
              const SizedBox(height: 8),

              // Comment input
              _CommentInput(
                controller: _commentController,
                focusNode: _focusNode,
                onSubmit: _submitComment,
                isLoading: provider.isLoading,
              ),
              const SizedBox(height: 16),

              // Comments list
              if (comments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'No comments yet. Be the first to comment!',
                      style: TextStyle(
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: comments.length > 5 ? 5 : comments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _CommentTile(comment: comments[index]);
                  },
                ),

              // View all comments button
              if (comments.length > 5)
                TextButton(
                  onPressed: () => _showAllComments(context, comments),
                  child: Text('View all ${comments.length} comments'),
                ),
            ],
          ],
        );
      },
    );
  }

  void _showAllComments(BuildContext context, List<CommentModel> comments) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'All Comments (${comments.length})',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: comments.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _CommentTile(comment: comments[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;
  final bool isLoading;

  const _CommentInput({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        UserAvatar(
          photoUrl: user?.profilePhotoUrl,
          initials: user?.initials ?? '?',
          radius: 16,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            maxLines: 3,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Add a comment...',
              hintStyle: TextStyle(
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              ),
              filled: true,
              fillColor: isDark ? AppTheme.darkSurface : AppTheme.backgroundGrey,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: isLoading ? null : onSubmit,
          icon: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send, color: AppTheme.primaryRed),
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  final CommentModel comment;

  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<UserProvider>().currentUser;
    final isOwner = currentUser?.id == comment.authorId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UserAvatar(
          photoUrl: comment.authorPhotoUrl,
          initials: comment.authorName.isNotEmpty
              ? comment.authorName[0].toUpperCase()
              : '?',
          radius: 14,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    comment.authorName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.primaryDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    comment.timeAgo,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                comment.content,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.primaryDark,
                ),
              ),
            ],
          ),
        ),
        if (isOwner)
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              size: 18,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            ),
            onSelected: (value) {
              if (value == 'delete') {
                _confirmDelete(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: AppTheme.primaryRed, size: 18),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: AppTheme.primaryRed)),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<CommentProvider>().deleteComment(comment.id);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
