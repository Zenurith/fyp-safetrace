import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/flag_model.dart';
import '../../data/repositories/flag_repository.dart';
import '../../utils/app_theme.dart';
import '../providers/user_provider.dart';

class FlagDialog extends StatefulWidget {
  final FlagTargetType targetType;
  final String targetId;

  const FlagDialog({
    super.key,
    required this.targetType,
    required this.targetId,
  });

  static Future<bool?> show(
    BuildContext context, {
    required FlagTargetType targetType,
    required String targetId,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => FlagDialog(
        targetType: targetType,
        targetId: targetId,
      ),
    );
  }

  @override
  State<FlagDialog> createState() => _FlagDialogState();
}

class _FlagDialogState extends State<FlagDialog> {
  final _detailsController = TextEditingController();
  String? _selectedReason;
  bool _isSubmitting = false;

  final _reasons = [
    'Spam or misleading',
    'Inappropriate content',
    'Harassment or abuse',
    'False information',
    'Privacy violation',
    'Other',
  ];

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null) return;

    final user = context.read<UserProvider>().currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    final flag = FlagModel(
      id: '',
      targetType: widget.targetType,
      targetId: widget.targetId,
      reporterId: user.id,
      reporterName: user.name,
      reason: _selectedReason!,
      details: _detailsController.text.trim().isNotEmpty
          ? _detailsController.text.trim()
          : null,
      createdAt: DateTime.now(),
    );

    try {
      await FlagRepository().add(flag);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted. Thank you for helping keep SafeTrace safe.'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit report: $e'),
            backgroundColor: AppTheme.primaryRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.flag, color: AppTheme.primaryRed),
          const SizedBox(width: 8),
          Text('Report ${widget.targetType.name}'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Why are you reporting this?',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.primaryDark,
              ),
            ),
            const SizedBox(height: 12),
            ...(_reasons.map((reason) => RadioListTile<String>(
                  title: Text(reason),
                  value: reason,
                  groupValue: _selectedReason,
                  onChanged: (value) => setState(() => _selectedReason = value),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppTheme.primaryRed,
                ))),
            const SizedBox(height: 16),
            TextField(
              controller: _detailsController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Additional details (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedReason != null && !_isSubmitting ? _submit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryRed,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Submit Report'),
        ),
      ],
    );
  }
}
