import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/models/audit_log_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/audit_log_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../utils/app_theme.dart';
import '../providers/user_provider.dart';

class UserModerationDialog extends StatefulWidget {
  final UserModel user;

  const UserModerationDialog({super.key, required this.user});

  static Future<bool?> show(BuildContext context, UserModel user) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => UserModerationDialog(user: user),
    );
  }

  @override
  State<UserModerationDialog> createState() => _UserModerationDialogState();
}

class _UserModerationDialogState extends State<UserModerationDialog> {
  final _reasonController = TextEditingController();
  final _repository = UserRepository();
  final _auditRepository = AuditLogRepository();
  bool _isLoading = false;
  int _suspensionDays = 7;

  void _logAction(String action, String detail) {
    final admin = context.read<UserProvider>().currentUser;
    if (admin == null) return;
    _auditRepository.create(AuditLogModel(
      id: '',
      adminId: admin.id,
      adminName: admin.name,
      action: action,
      targetType: 'user',
      targetId: widget.user.id,
      detail: detail,
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _banUser() async {
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a reason'),
          backgroundColor: AppTheme.primaryRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _repository.banUser(widget.user.id, _reasonController.text.trim());
      _logAction('Banned user: ${widget.user.name}',
          'Reason: ${_reasonController.text.trim()}');
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.user.name} has been banned'),
            backgroundColor: AppTheme.primaryRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _suspendUser() async {
    setState(() => _isLoading = true);

    try {
      final until = DateTime.now().add(Duration(days: _suspensionDays));
      await _repository.suspendUser(widget.user.id, until);
      _logAction('Suspended user: ${widget.user.name}',
          'Suspended until ${DateFormat('MMM d, y').format(until)}');
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.user.name} suspended until ${DateFormat('MMM d, y').format(until)}',
            ),
            backgroundColor: AppTheme.warningOrange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _unbanUser() async {
    setState(() => _isLoading = true);

    try {
      await _repository.unbanUser(widget.user.id);
      _logAction('Unbanned user: ${widget.user.name}', '');
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.user.name} has been unbanned'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _unsuspendUser() async {
    setState(() => _isLoading = true);

    try {
      await _repository.unsuspendUser(widget.user.id);
      _logAction('Lifted suspension: ${widget.user.name}', '');
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.user.name} suspension lifted'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.admin_panel_settings, color: AppTheme.primaryDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Moderate ${user.name}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundGrey,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('User ID', user.id),
                  _buildInfoRow('Handle', user.handle),
                  _buildInfoRow('Points', '${user.points}'),
                  _buildInfoRow('Reports', '${user.reports}'),
                  if (user.isBanned) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.block, color: AppTheme.primaryRed, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'BANNED',
                            style: const TextStyle(
                              color: AppTheme.primaryRed,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (user.banReason != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Reason: ${user.banReason}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                  ],
                  if (user.isActivelySuspended) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.warningOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer, color: AppTheme.warningOrange, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Suspended until ${DateFormat('MMM d').format(user.suspendedUntil!)}',
                            style: const TextStyle(
                              color: AppTheme.warningOrange,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Actions based on current status
            if (user.isBanned) ...[
              Text(
                'This user is currently banned.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _unbanUser,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Unban User'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successGreen,
                  ),
                ),
              ),
            ] else if (user.isActivelySuspended) ...[
              Text(
                'This user is currently suspended.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _unsuspendUser,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Lift Suspension'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successGreen,
                  ),
                ),
              ),
            ] else ...[
              // Suspend option
              Text(
                'Suspend User',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryDark,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _suspensionDays.toDouble(),
                      min: 1,
                      max: 30,
                      divisions: 29,
                      label: '$_suspensionDays days',
                      onChanged: (value) =>
                          setState(() => _suspensionDays = value.round()),
                    ),
                  ),
                  Text('$_suspensionDays days'),
                ],
              ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _suspendUser,
                  icon: const Icon(Icons.timer),
                  label: Text('Suspend for $_suspensionDays days'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.warningOrange,
                    side: const BorderSide(color: AppTheme.warningOrange),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Ban option
              Text(
                'Ban User (Permanent)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryDark,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reasonController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Reason for ban (required)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _banUser,
                  icon: const Icon(Icons.block),
                  label: const Text('Ban User'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryRed,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
