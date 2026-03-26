import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/post_model.dart';
import '../../utils/app_theme.dart';
import '../providers/post_provider.dart';
import '../providers/user_provider.dart';

/// A modal bottom sheet for creating a new community post.
/// Show with: showModalBottomSheet(isScrollControlled: true, builder: (_) => CreatePostSheet(...))
class CreatePostSheet extends StatefulWidget {
  final String communityId;

  const CreatePostSheet({super.key, required this.communityId});

  @override
  State<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<CreatePostSheet> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  PostVisibility _visibility = PostVisibility.private;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final userId = context.read<UserProvider>().currentUser?.id ?? '';
    final post = PostModel(
      id: '',
      authorId: userId,
      communityId: widget.communityId,
      visibility: _visibility,
      title: title,
      content: _contentController.text.trim(),
      createdAt: DateTime.now(),
    );

    final success = await context.read<PostProvider>().createPost(post);

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                context.read<PostProvider>().error ?? 'Failed to create post'),
            backgroundColor: AppTheme.primaryRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('New Post', style: AppTheme.headingMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Title *',
              counterText: '',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryRed),
              ),
            ),
            textCapitalization: TextCapitalization.sentences,
            maxLength: 120,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contentController,
            decoration: InputDecoration(
              labelText: 'Details (optional)',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryRed),
              ),
            ),
            textCapitalization: TextCapitalization.sentences,
            maxLines: 4,
            maxLength: 1000,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Visible to:', style: AppTheme.bodyMedium),
              const SizedBox(width: 12),
              ChoiceChip(
                label: const Text('Community only'),
                selected: _visibility == PostVisibility.private,
                selectedColor: AppTheme.primaryRed.withValues(alpha: 0.15),
                onSelected: (_) =>
                    setState(() => _visibility = PostVisibility.private),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Public'),
                selected: _visibility == PostVisibility.public,
                selectedColor: AppTheme.primaryRed.withValues(alpha: 0.15),
                onSelected: (_) =>
                    setState(() => _visibility = PostVisibility.public),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Post'),
            ),
          ),
        ],
      ),
    );
  }
}
