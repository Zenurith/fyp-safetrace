import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/flag_thread_provider.dart';
import '../providers/user_provider.dart';
import '../../data/models/flag_thread_model.dart';
import '../../utils/app_theme.dart';
import 'flag_thread_screen.dart';
import '../../data/repositories/flag_repository.dart';
import '../../data/models/flag_model.dart';

class FlagInboxScreen extends StatefulWidget {
  const FlagInboxScreen({super.key});

  @override
  State<FlagInboxScreen> createState() => _FlagInboxScreenState();
}

class _FlagInboxScreenState extends State<FlagInboxScreen> {
  late final FlagThreadProvider _threadProvider;
  late final String? _currentUserId;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>().currentUser;
    _currentUserId = user?.id;
    _threadProvider = context.read<FlagThreadProvider>();
    if (_currentUserId != null) {
      _threadProvider.loadUserThreads(_currentUserId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final threads = context.watch<FlagThreadProvider>().userThreads;
    final userId = _currentUserId ?? '';

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
        title: const Text(
          'Message Inbox',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
      ),
      body: threads.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 64,
                      color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text('No messages yet',
                      style: AppTheme.bodyLarge
                          .copyWith(color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Text(
                    'Updates about your reports will appear here.',
                    style: AppTheme.caption,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: threads.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _ThreadCard(
                thread: threads[i],
                currentUserId: userId,
              ),
            ),
    );
  }
}

class _ThreadCard extends StatefulWidget {
  final FlagThreadModel thread;
  final String currentUserId;

  const _ThreadCard({required this.thread, required this.currentUserId});

  @override
  State<_ThreadCard> createState() => _ThreadCardState();
}

class _ThreadCardState extends State<_ThreadCard> {
  FlagModel? _flag;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    FlagRepository().getAll().then((flags) {
      final match = flags.cast<FlagModel?>().firstWhere(
            (f) => f?.id == widget.thread.flagId,
            orElse: () => null,
          );
      if (mounted) setState(() { _flag = match; _loaded = true; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final unread = widget.thread.unreadFor(widget.currentUserId);
    final isClosed = widget.thread.isClosed;

    return GestureDetector(
      onTap: () {
        if (_flag == null || isClosed) return;
        final participants = widget.thread.participants;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FlagThreadScreen(
              flag: _flag!,
              participants: participants,
            ),
          ),
        );
      },
      child: Opacity(
        opacity: isClosed ? 0.55 : 1.0,
        child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.cardDecoration,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isClosed
                    ? AppTheme.textSecondary.withValues(alpha: 0.08)
                    : AppTheme.primaryDark.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isClosed ? Icons.lock_outline : Icons.chat_bubble_outline,
                size: 20,
                color: isClosed ? AppTheme.textSecondary : AppTheme.primaryDark,
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _loaded
                              ? (_flag?.reason ?? 'Flag Report')
                              : 'Loading…',
                          style: AppTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isClosed)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.textSecondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Closed',
                            style: AppTheme.caption.copyWith(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      else if (unread > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryRed,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unread',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontFamily: AppTheme.fontFamily,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (isClosed)
                    Text(
                      'This thread has been closed.',
                      style: AppTheme.caption
                          .copyWith(color: AppTheme.textSecondary),
                    )
                  else if (widget.thread.lastMessage.isNotEmpty)
                    Text(
                      widget.thread.lastMessage,
                      style: AppTheme.caption.copyWith(
                        color: unread > 0
                            ? AppTheme.primaryDark
                            : AppTheme.textSecondary,
                        fontWeight: unread > 0
                            ? FontWeight.w600
                            : FontWeight.w300,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Text(widget.thread.formattedTime,
                      style: AppTheme.caption
                          .copyWith(color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
