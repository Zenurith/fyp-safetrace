import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/comment_model.dart';
import '../../data/models/flag_model.dart';
import '../../utils/app_theme.dart';
import '../providers/comment_provider.dart';
import '../providers/user_provider.dart';
import 'flag_dialog.dart';
import 'user_avatar.dart';

/// Tappable row showing comment count; opens [_CommentsSheet] on tap.
class CommentsSection extends StatefulWidget {
  final String incidentId;
  final String? communityId;

  const CommentsSection({super.key, required this.incidentId, this.communityId});

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  late CommentProvider _commentProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _commentProvider = context.read<CommentProvider>();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _commentProvider.startListening(widget.incidentId);
    });
  }

  @override
  void dispose() {
    _commentProvider.stopListening(widget.incidentId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CommentProvider>(
      builder: (context, provider, _) {
        final count = provider.getComments(widget.incidentId).length;
        return InkWell(
          onTap: () => _CommentsSheet.show(context, widget.incidentId, widget.communityId),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(Icons.comment_outlined, size: 18, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Text(
                  'Comments',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryDark,
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
                    '$count',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryRed,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(Icons.chevron_right, color: AppTheme.textSecondary),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  final String incidentId;
  final String? communityId;

  const _CommentsSheet({required this.incidentId, this.communityId});

  static void show(BuildContext context, String incidentId, String? communityId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(incidentId: incidentId, communityId: communityId),
    );
  }

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _editController = TextEditingController();
  String? _editingCommentId;

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    _editController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final user = context.read<UserProvider>().currentUser;
    if (user == null) return;

    if (!user.canAccessApp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your account has been suspended or banned.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final content = _inputController.text.trim();
    if (content.isEmpty) return;

    final success = await context.read<CommentProvider>().addComment(
          incidentId: widget.incidentId,
          authorId: user.id,
          authorName: user.name,
          authorPhotoUrl: user.profilePhotoUrl,
          content: content,
        );

    if (success && mounted) {
      _inputController.clear();
      _inputFocusNode.unfocus();
    }
  }

  Future<void> _saveEdit(String commentId) async {
    final content = _editController.text.trim();
    if (content.isEmpty) return;

    final success = await context.read<CommentProvider>().updateComment(commentId, content);
    if (success && mounted) {
      setState(() => _editingCommentId = null);
      _editController.clear();
    }
  }

  void _startEdit(CommentModel comment) {
    _editController.text = comment.content;
    setState(() => _editingCommentId = comment.id);
  }

  void _cancelEdit() {
    setState(() => _editingCommentId = null);
    _editController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Consumer<CommentProvider>(
              builder: (context, provider, _) {
                final count = provider.getComments(widget.incidentId).length;
                return Row(
                  children: [
                    Text(
                      'Comments',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryDark,
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
                        '$count',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryRed,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),

          // Comments list
          Flexible(
            child: Consumer<CommentProvider>(
              builder: (context, provider, _) {
                final comments = provider.getComments(widget.incidentId);
                if (comments.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'No comments yet.\nBe the first to comment!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: comments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return _CommentTile(
                      comment: comment,
                      communityId: widget.communityId,
                      isEditing: _editingCommentId == comment.id,
                      editController: _editController,
                      onStartEdit: () => _startEdit(comment),
                      onSaveEdit: () => _saveEdit(comment.id),
                      onCancelEdit: _cancelEdit,
                    );
                  },
                );
              },
            ),
          ),

          // Sticky comment input
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
            child: Consumer<CommentProvider>(
              builder: (context, provider, _) {
                final user = context.watch<UserProvider>().currentUser;
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
                        controller: _inputController,
                        focusNode: _inputFocusNode,
                        maxLines: 3,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: TextStyle(color: AppTheme.textSecondary),
                          filled: true,
                          fillColor: AppTheme.backgroundGrey,
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
                    IconButton(
                      onPressed: provider.isLoading ? null : _submitComment,
                      icon: provider.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send, color: AppTheme.primaryRed),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final CommentModel comment;
  final String? communityId;
  final bool isEditing;
  final TextEditingController editController;
  final VoidCallback onStartEdit;
  final VoidCallback onSaveEdit;
  final VoidCallback onCancelEdit;

  const _CommentTile({
    required this.comment,
    this.communityId,
    required this.isEditing,
    required this.editController,
    required this.onStartEdit,
    required this.onSaveEdit,
    required this.onCancelEdit,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<UserProvider>().currentUser;
    final isOwner = currentUser?.id == comment.authorId;
    final isAdmin = currentUser?.isAdmin ?? false;
    final canDelete = isOwner || isAdmin;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UserAvatar(
          photoUrl: comment.authorPhotoUrl,
          initials: comment.authorName.isNotEmpty
              ? comment.authorName[0].toUpperCase()
              : '?',
          radius: 16,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author + time
              Row(
                children: [
                  Text(
                    comment.authorName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    comment.timeAgo,
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Inline edit mode or comment text
              if (isEditing) ...[
                TextField(
                  controller: editController,
                  autofocus: true,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppTheme.backgroundGrey,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: onCancelEdit,
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        textStyle: const TextStyle(fontSize: 13),
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: onSaveEdit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryRed,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(fontSize: 13),
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ] else
                Text(
                  comment.content,
                  style: const TextStyle(fontSize: 14, color: AppTheme.primaryDark),
                ),
            ],
          ),
        ),
        if (!isEditing)
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 18, color: AppTheme.textSecondary),
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  onStartEdit();
                case 'delete':
                  _confirmDelete(context);
                case 'report_comment':
                  FlagDialog.show(
                    context,
                    targetType: FlagTargetType.comment,
                    targetId: comment.id,
                    communityId: communityId,
                  );
                case 'report_user':
                  FlagDialog.show(
                    context,
                    targetType: FlagTargetType.user,
                    targetId: comment.authorId,
                    communityId: communityId,
                  );
              }
            },
            itemBuilder: (context) => [
              if (isOwner)
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
              if (canDelete)
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
              if (!isOwner) ...[
                const PopupMenuItem(
                  value: 'report_comment',
                  child: Row(
                    children: [
                      Icon(Icons.flag_outlined, size: 18, color: AppTheme.warningOrange),
                      SizedBox(width: 8),
                      Text('Report comment'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'report_user',
                  child: Row(
                    children: [
                      Icon(Icons.person_off_outlined, size: 18, color: AppTheme.primaryRed),
                      SizedBox(width: 8),
                      Text('Report user'),
                    ],
                  ),
                ),
              ],
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
