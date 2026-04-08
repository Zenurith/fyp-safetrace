import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/audit_log_model.dart';
import '../../data/models/flag_message_model.dart';
import '../../data/models/flag_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/audit_log_repository.dart';
import '../../data/repositories/community_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../utils/app_theme.dart';
import '../providers/flag_provider.dart';
import '../providers/flag_thread_provider.dart';
import '../providers/user_provider.dart';

class FlagThreadDialog extends StatefulWidget {
  final FlagModel flag;
  final List<String> participants;

  const FlagThreadDialog({
    super.key,
    required this.flag,
    required this.participants,
  });

  @override
  State<FlagThreadDialog> createState() => _FlagThreadDialogState();
}

class _FlagThreadDialogState extends State<FlagThreadDialog> {
  final _messageController = TextEditingController();
  final _resolveNoteController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  bool _showResolvePanel = false;

  late UserModel? _currentUser;
  late FlagThreadProvider _threadProvider;

  @override
  void initState() {
    super.initState();
    _currentUser = context.read<UserProvider>().currentUser;
    _threadProvider = context.read<FlagThreadProvider>();
    _threadProvider.openThread(
      widget.flag.id,
      widget.participants,
      _currentUser?.id ?? '',
      initialClosed: widget.flag.status != FlagStatus.pending,
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _resolveNoteController.dispose();
    _scrollController.dispose();
    _threadProvider.closeThread();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _currentUser == null) return;
    setState(() => _isSending = true);
    _messageController.clear();
    await _threadProvider.sendMessage(
      flagId: widget.flag.id,
      content: content,
      senderId: _currentUser!.id,
      senderName: _currentUser!.name,
      senderRole: 'admin',
      participants: widget.participants,
    );
    setState(() => _isSending = false);
    _scrollToBottom();
  }

  Future<void> _resolve() async {
    final note = _resolveNoteController.text.trim();
    final flagProvider = context.read<FlagProvider>();
    final ok = await flagProvider.resolveFlag(
      widget.flag.id,
      resolvedBy: _currentUser?.id,
      note: note.isEmpty ? null : note,
    );
    if (ok && _currentUser != null) {
      AuditLogRepository().create(AuditLogModel(
        id: '',
        adminId: _currentUser!.id,
        adminName: _currentUser!.name,
        action: 'Resolved flag',
        targetType: 'flag',
        targetId: widget.flag.id,
        detail: note.isEmpty ? 'Reason: ${widget.flag.reason}' : note,
        timestamp: DateTime.now(),
      ));
    }
    if (ok) await _threadProvider.closeActiveThread();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _dismiss() async {
    final note = _resolveNoteController.text.trim();
    final flagProvider = context.read<FlagProvider>();
    final ok = await flagProvider.dismissFlag(
      widget.flag.id,
      resolvedBy: _currentUser?.id,
      note: note.isEmpty ? null : note,
    );
    if (ok && _currentUser != null) {
      AuditLogRepository().create(AuditLogModel(
        id: '',
        adminId: _currentUser!.id,
        adminName: _currentUser!.name,
        action: 'Dismissed flag',
        targetType: 'flag',
        targetId: widget.flag.id,
        detail: note.isEmpty ? 'Reason: ${widget.flag.reason}' : note,
        timestamp: DateTime.now(),
      ));
    }
    if (ok) await _threadProvider.closeActiveThread();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _tempBan(int days) async {
    final note = _resolveNoteController.text.trim();
    final reason = note.isEmpty ? 'Suspended by administrator.' : note;
    final until = DateTime.now().add(Duration(days: days));
    try {
      await UserRepository().suspendUser(widget.flag.targetId, until);
      if (!mounted) return;
      final suspension = 'User suspended for $days ${days == 1 ? 'day' : 'days'}. $reason';
      await context.read<FlagProvider>().resolveFlag(
            widget.flag.id,
            resolvedBy: _currentUser?.id,
            note: suspension,
          );
      if (_currentUser != null) {
        AuditLogRepository().create(AuditLogModel(
          id: '',
          adminId: _currentUser!.id,
          adminName: _currentUser!.name,
          action: 'Suspended user ($days days)',
          targetType: 'user',
          targetId: widget.flag.targetId,
          detail: suspension,
          timestamp: DateTime.now(),
        ));
      }
      await _threadProvider.closeActiveThread();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to suspend user: $e'),
          backgroundColor: AppTheme.primaryRed,
        ));
      }
    }
  }

  Future<void> _permaBan() async {
    final note = _resolveNoteController.text.trim();
    if (note.isEmpty) return; // perma-ban requires a reason
    try {
      await UserRepository().banUser(widget.flag.targetId, note);
      if (!mounted) return;
      final banNote = 'User permanently banned. $note';
      await context.read<FlagProvider>().resolveFlag(
            widget.flag.id,
            resolvedBy: _currentUser?.id,
            note: banNote,
          );
      if (_currentUser != null) {
        AuditLogRepository().create(AuditLogModel(
          id: '',
          adminId: _currentUser!.id,
          adminName: _currentUser!.name,
          action: 'Permanently banned user',
          targetType: 'user',
          targetId: widget.flag.targetId,
          detail: banNote,
          timestamp: DateTime.now(),
        ));
      }
      await _threadProvider.closeActiveThread();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to ban user: $e'),
          backgroundColor: AppTheme.primaryRed,
        ));
      }
    }
  }

  Future<void> _deleteCommunity() async {
    final communityName = widget.flag.targetId;
    try {
      await CommunityRepository().delete(widget.flag.targetId);
      if (!mounted) return;
      await context.read<FlagProvider>().resolveFlag(
            widget.flag.id,
            resolvedBy: _currentUser?.id,
            note: 'Community deleted by administrator.',
          );
      if (_currentUser != null) {
        AuditLogRepository().create(AuditLogModel(
          id: '',
          adminId: _currentUser!.id,
          adminName: _currentUser!.name,
          action: 'Deleted community',
          targetType: 'community',
          targetId: widget.flag.targetId,
          detail: 'Community "$communityName" deleted via flag review.',
          timestamp: DateTime.now(),
        ));
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to delete community: $e'),
          backgroundColor: AppTheme.primaryRed,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final threadProvider = context.watch<FlagThreadProvider>();
    final messages = threadProvider.messages;
    final isPending = widget.flag.status == FlagStatus.pending;
    final isEscalated = widget.flag.escalatedToAdmin;
    final isCommunityFlag =
        widget.flag.targetType == FlagTargetType.community;
    final isUserFlag = widget.flag.targetType == FlagTargetType.user;

    // Scroll when new messages arrive.
    if (messages.isNotEmpty) _scrollToBottom();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 560,
        height: 680,
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: BoxDecoration(
                color: AppTheme.primaryDark,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  _TypeChip(flag: widget.flag),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.flag.reason,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _StatusPill(status: widget.flag.status),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ── Message list ──────────────────────────────────────────────
            Expanded(
              child: threadProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_outline,
                                  size: 48,
                                  color: AppTheme.cardBorder),
                              const SizedBox(height: 12),
                              Text('No messages yet',
                                  style: AppTheme.bodyMedium.copyWith(
                                      color: AppTheme.textSecondary)),
                              const SizedBox(height: 4),
                              Text('Start the conversation below.',
                                  style: AppTheme.caption),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: messages.length,
                          itemBuilder: (_, i) => _MessageBubble(
                            message: messages[i],
                            isOwn: messages[i].senderId ==
                                _currentUser?.id,
                          ),
                        ),
            ),

            // ── Compose ───────────────────────────────────────────────────
            if (threadProvider.isActiveClosed)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: const BoxDecoration(
                  color: AppTheme.backgroundGrey,
                  border: Border(top: BorderSide(color: AppTheme.cardBorder)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_outline,
                        size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      'This thread has been closed.',
                      style: AppTheme.caption
                          .copyWith(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              )
            else
            Container(
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(color: AppTheme.cardBorder)),
              ),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: AppTheme.bodyMedium,
                      maxLines: 3,
                      minLines: 1,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Write a message…',
                        hintStyle: AppTheme.caption,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AppTheme.cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AppTheme.cardBorder),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isSending ? null : _sendMessage,
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                    color: AppTheme.primaryDark,
                  ),
                ],
              ),
            ),

            // ── Resolution panel ──────────────────────────────────────────
            if (isPending || isEscalated)
              _ResolutionPanel(
                flag: widget.flag,
                isEscalated: isEscalated,
                isCommunityFlag: isCommunityFlag,
                isUserFlag: isUserFlag,
                noteController: _resolveNoteController,
                showPanel: _showResolvePanel,
                onToggle: () =>
                    setState(() => _showResolvePanel = !_showResolvePanel),
                onResolve: _resolve,
                onDismiss: _dismiss,
                onTempBan: _tempBan,
                onPermaBan: _permaBan,
                onDeleteCommunity: _deleteCommunity,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Resolution panel ───────────────────────────────────────────────────────────

class _ResolutionPanel extends StatefulWidget {
  final FlagModel flag;
  final bool isEscalated;
  final bool isCommunityFlag;
  final bool isUserFlag;
  final TextEditingController noteController;
  final bool showPanel;
  final VoidCallback onToggle;
  final VoidCallback onResolve;
  final VoidCallback onDismiss;
  final void Function(int days) onTempBan;
  final VoidCallback onPermaBan;
  final VoidCallback onDeleteCommunity;

  const _ResolutionPanel({
    required this.flag,
    required this.isEscalated,
    required this.isCommunityFlag,
    required this.isUserFlag,
    required this.noteController,
    required this.showPanel,
    required this.onToggle,
    required this.onResolve,
    required this.onDismiss,
    required this.onTempBan,
    required this.onPermaBan,
    required this.onDeleteCommunity,
  });

  @override
  State<_ResolutionPanel> createState() => _ResolutionPanelState();
}

class _ResolutionPanelState extends State<_ResolutionPanel> {
  int _selectedDays = 7;
  static const _durations = [1, 3, 7, 14, 30];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundGrey,
        border: Border(top: BorderSide(color: AppTheme.cardBorder)),
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Toggle row
          InkWell(
            onTap: widget.onToggle,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.gavel_outlined,
                      size: 16, color: AppTheme.primaryRed),
                  const SizedBox(width: 8),
                  Text('Take Action',
                      style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.primaryRed,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Icon(
                    widget.showPanel
                        ? Icons.expand_more
                        : Icons.chevron_right,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          if (widget.showPanel) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Resolution note field
                  TextField(
                    controller: widget.noteController,
                    style: AppTheme.bodyMedium,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: widget.isEscalated && widget.isUserFlag
                          ? 'Resolution note / ban reason…'
                          : 'Resolution note (optional)…',
                      hintStyle: AppTheme.caption,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: AppTheme.cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: AppTheme.cardBorder),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Temp ban duration (escalated user flags only)
                  if (widget.isEscalated && widget.isUserFlag) ...[
                    Text('Suspension duration:',
                        style: AppTheme.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: _durations.map((days) {
                        final selected = _selectedDays == days;
                        return ChoiceChip(
                          label: Text('${days}d',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? Colors.white
                                    : AppTheme.primaryDark,
                              )),
                          selected: selected,
                          selectedColor: AppTheme.warningOrange,
                          backgroundColor: Colors.white,
                          side: BorderSide(
                              color: selected
                                  ? AppTheme.warningOrange
                                  : AppTheme.cardBorder),
                          onSelected: (_) =>
                              setState(() => _selectedDays = days),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Action buttons
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      // Community flags: delete community
                      if (widget.isCommunityFlag)
                        _ActionButton(
                          label: 'Delete Community',
                          color: AppTheme.primaryRed,
                          onPressed: widget.onDeleteCommunity,
                        ),

                      // Escalated user flags: temp ban + perma ban
                      if (widget.isEscalated && widget.isUserFlag) ...[
                        _ActionButton(
                          label: 'Temp Ban (${_selectedDays}d)',
                          color: AppTheme.warningOrange,
                          onPressed: () =>
                              widget.onTempBan(_selectedDays),
                        ),
                        StatefulBuilder(
                          builder: (_, setBtn) => _ActionButton(
                            label: 'Perma Ban',
                            color: AppTheme.primaryRed,
                            onPressed: widget.noteController.text
                                    .trim()
                                    .isEmpty
                                ? null
                                : widget.onPermaBan,
                          ),
                        ),
                      ],

                      // Always: resolve + dismiss
                      _ActionButton(
                        label: 'Resolve',
                        color: AppTheme.successGreen,
                        onPressed: widget.onResolve,
                      ),
                      _ActionButton(
                        label: 'Dismiss',
                        color: AppTheme.textSecondary,
                        onPressed: widget.onDismiss,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const _ActionButton(
      {required this.label, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        textStyle: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Text(label),
    );
  }
}

// ── Message bubble ─────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final FlagMessageModel message;
  final bool isOwn;

  const _MessageBubble({required this.message, required this.isOwn});

  Color get _roleColor {
    switch (message.senderRole) {
      case 'admin':
        return AppTheme.primaryRed;
      case 'staff':
        return AppTheme.warningOrange;
      default:
        return AppTheme.primaryDark;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isOwn) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: _roleColor.withValues(alpha: 0.15),
              child: Text(
                message.senderName.isNotEmpty
                    ? message.senderName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _roleColor),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isOwn
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isOwn) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(message.senderName,
                          style: AppTheme.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryDark)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: _roleColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          message.senderRole.toUpperCase(),
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _roleColor,
                              fontFamily: AppTheme.fontFamily),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isOwn
                        ? AppTheme.primaryDark
                        : AppTheme.backgroundGrey,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(12),
                      topRight: const Radius.circular(12),
                      bottomLeft: Radius.circular(isOwn ? 12 : 2),
                      bottomRight: Radius.circular(isOwn ? 2 : 12),
                    ),
                    border: isOwn
                        ? null
                        : Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Text(
                    message.content,
                    style: AppTheme.bodyMedium.copyWith(
                      color:
                          isOwn ? Colors.white : AppTheme.primaryDark,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(message.timeAgo, style: AppTheme.caption),
              ],
            ),
          ),
          if (isOwn) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ── Small helpers ──────────────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  final FlagModel flag;
  const _TypeChip({required this.flag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        flag.targetTypeLabel.toUpperCase(),
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final FlagStatus status;
  const _StatusPill({required this.status});

  Color get _color {
    switch (status) {
      case FlagStatus.pending:
        return AppTheme.warningOrange;
      case FlagStatus.reviewed:
        return Colors.white60;
      case FlagStatus.resolved:
        return AppTheme.successGreen;
      case FlagStatus.dismissed:
        return Colors.white38;
    }
  }

  String get _label {
    switch (status) {
      case FlagStatus.pending:
        return 'PENDING';
      case FlagStatus.reviewed:
        return 'REVIEWED';
      case FlagStatus.resolved:
        return 'RESOLVED';
      case FlagStatus.dismissed:
        return 'DISMISSED';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _color.withValues(alpha: 0.5)),
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: _color,
        ),
      ),
    );
  }
}
