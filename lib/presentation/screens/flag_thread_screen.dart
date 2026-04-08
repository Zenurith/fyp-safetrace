import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/flag_provider.dart';
import '../providers/flag_thread_provider.dart';
import '../providers/user_provider.dart';
import '../../data/models/flag_message_model.dart';
import '../../data/models/flag_model.dart';
import '../../utils/app_theme.dart';

class FlagThreadScreen extends StatefulWidget {
  final FlagModel flag;
  final List<String> participants;
  /// Override the auto-detected sender role. Pass 'staff' for community managers,
  /// 'admin' for system admins, 'reporter' for regular users. Defaults to auto-detect.
  final String? senderRole;

  const FlagThreadScreen({
    super.key,
    required this.flag,
    required this.participants,
    this.senderRole,
  });

  @override
  State<FlagThreadScreen> createState() => _FlagThreadScreenState();
}

class _FlagThreadScreenState extends State<FlagThreadScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  late final FlagThreadProvider _threadProvider;
  late final String? _currentUserId;
  late final String _currentUserName;
  late final String _senderRole;

  @override
  void initState() {
    super.initState();
    final userProvider = context.read<UserProvider>();
    final user = userProvider.currentUser;
    _currentUserId = user?.id;
    _currentUserName = user?.name ?? 'Unknown';
    _senderRole = widget.senderRole ??
        ((user?.isAdmin ?? false) ? 'admin' : 'reporter');

    _threadProvider = context.read<FlagThreadProvider>();
    _threadProvider.openThread(
      widget.flag.id,
      widget.participants,
      _currentUserId ?? '',
      initialClosed: widget.flag.status != FlagStatus.pending,
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
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
    if (content.isEmpty || _currentUserId == null || _threadProvider.isActiveClosed) return;
    setState(() => _isSending = true);
    _messageController.clear();
    await _threadProvider.sendMessage(
      flagId: widget.flag.id,
      content: content,
      senderId: _currentUserId!,
      senderName: _currentUserName,
      senderRole: _senderRole,
      participants: widget.participants,
    );
    setState(() => _isSending = false);
    _scrollToBottom();
  }

  void _showActionSheet(BuildContext context) {
    final noteController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Take Action', style: AppTheme.headingSmall),
            const SizedBox(height: 4),
            Text(
              'Resolve or dismiss this flag. Add a note describing the action taken.',
              style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              style: AppTheme.bodyMedium,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Resolution note (optional)…',
                hintStyle: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.primaryDark, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final note = noteController.text.trim();
                      Navigator.pop(ctx);
                      final ok = await context.read<FlagProvider>().dismissFlag(
                        widget.flag.id,
                        resolvedBy: _currentUserId,
                        note: note.isEmpty ? null : note,
                      );
                      if (ok && mounted) {
                        await _threadProvider.closeActiveThread();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Flag dismissed'),
                            backgroundColor: AppTheme.textSecondary,
                          ),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: const BorderSide(color: AppTheme.cardBorder),
                    ),
                    child: const Text('Dismiss'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final note = noteController.text.trim();
                      Navigator.pop(ctx);
                      final ok = await context.read<FlagProvider>().resolveFlag(
                        widget.flag.id,
                        resolvedBy: _currentUserId,
                        note: note.isEmpty ? null : note,
                      );
                      if (ok && mounted) {
                        await _threadProvider.closeActiveThread();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Flag resolved'),
                            backgroundColor: AppTheme.successGreen,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successGreen,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Resolve'),
                  ),
                ),
              ],
            ),
            // Escalate to Admin — only for user-type flags
            if (widget.flag.targetType == FlagTargetType.user) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.admin_panel_settings_outlined, size: 16),
                  label: const Text('Escalate to System Admin'),
                  onPressed: () async {
                    final note = noteController.text.trim();
                    Navigator.pop(ctx);
                    final ok = await context.read<FlagProvider>().escalateToAdmin(
                      widget.flag.id,
                      escalatedBy: _currentUserId ?? '',
                      note: note.isEmpty ? null : note,
                    );
                    if (ok && mounted) {
                      await _threadProvider.closeActiveThread();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Escalated to system admin'),
                          backgroundColor: AppTheme.primaryDark,
                        ),
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryDark,
                    side: const BorderSide(color: AppTheme.primaryDark),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final threadProvider = context.watch<FlagThreadProvider>();
    final messages = threadProvider.messages;

    if (messages.isNotEmpty) _scrollToBottom();

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Flag Thread',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            Text(
              widget.flag.targetTypeLabel,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          if (_senderRole == 'staff' &&
              widget.flag.status == FlagStatus.pending)
            IconButton(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Take Action',
              onPressed: () => _showActionSheet(context),
            ),
        ],
      ),
      body: Column(
        children: [
          // Flag context banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppTheme.backgroundGrey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reason: ${widget.flag.reason}',
                  style: AppTheme.caption.copyWith(
                    color: AppTheme.primaryDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.flag.details != null &&
                    widget.flag.details!.isNotEmpty)
                  Text(widget.flag.details!,
                      style: AppTheme.caption
                          .copyWith(color: AppTheme.textSecondary)),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: threadProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 56, color: AppTheme.cardBorder),
                            const SizedBox(height: 12),
                            Text('No messages yet',
                                style: AppTheme.bodyLarge.copyWith(
                                    color: AppTheme.textSecondary)),
                            const SizedBox(height: 4),
                            Text('Updates about this report will appear here.',
                                style: AppTheme.caption),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount: messages.length,
                        itemBuilder: (_, i) => _MessageBubble(
                          message: messages[i],
                          isOwn: messages[i].senderId == _currentUserId,
                        ),
                      ),
          ),

          // Compose — hidden when thread is closed
          if (threadProvider.isActiveClosed)
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  MediaQuery.of(context).padding.bottom + 12),
              decoration: const BoxDecoration(
                color: AppTheme.backgroundGrey,
                border: Border(top: BorderSide(color: AppTheme.cardBorder)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline,
                      size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    'This thread has been closed.',
                    style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            )
          else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                  top: BorderSide(color: AppTheme.cardBorder)),
            ),
            padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.of(context).viewInsets.bottom +
                    MediaQuery.of(context).padding.bottom +
                    8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: AppTheme.bodyMedium,
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: 'Write a message…',
                      hintStyle:
                          AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide:
                            const BorderSide(color: AppTheme.cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide:
                            const BorderSide(color: AppTheme.cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(
                            color: AppTheme.primaryDark, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _isSending ? null : _sendMessage,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _isSending
                          ? AppTheme.textSecondary
                          : AppTheme.primaryDark,
                      shape: BoxShape.circle,
                    ),
                    child: _isSending
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send,
                            color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
              radius: 16,
              backgroundColor: _roleColor.withValues(alpha: 0.15),
              child: Text(
                message.senderName.isNotEmpty
                    ? message.senderName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _roleColor),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isOwn) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.senderName,
                        style: AppTheme.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryDark),
                      ),
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
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isOwn
                        ? AppTheme.primaryDark
                        : AppTheme.backgroundGrey,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isOwn ? 16 : 2),
                      bottomRight: Radius.circular(isOwn ? 2 : 16),
                    ),
                    border: isOwn
                        ? null
                        : Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Text(
                    message.content,
                    style: AppTheme.bodyMedium.copyWith(
                      color: isOwn ? Colors.white : AppTheme.primaryDark,
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
