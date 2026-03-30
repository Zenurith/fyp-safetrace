part of '../community_manager_screen.dart';

// ── Pending Requests Tab ─────────────────────────────────────────────────────

class _PendingRequestsTab extends StatefulWidget {
  final String communityId;
  final Future<void> Function() onRefresh;

  const _PendingRequestsTab({
    required this.communityId,
    required this.onRefresh,
  });

  @override
  State<_PendingRequestsTab> createState() => _PendingRequestsTabState();
}

class _PendingRequestsTabState extends State<_PendingRequestsTab> {
  final Set<String> _requestedIds = {};
  final Map<String, UserModel?> _users = {};
  final Set<String> _selectedIds = {};
  bool _isBulkProcessing = false;

  void _loadMissingUsers(List<CommunityMemberModel> requests) {
    final missing = requests
        .map((r) => r.userId)
        .where((id) => !_requestedIds.contains(id))
        .toList();
    if (missing.isEmpty) return;
    for (final id in missing) {
      _requestedIds.add(id);
    }
    context.read<UserProvider>().getUsersByIds(missing).then((fetched) {
      if (mounted) setState(() => _users.addAll(fetched));
    });
  }

  Future<void> _bulkApprove(List<CommunityMemberModel> requests) async {
    final ids = _selectedIds.toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Selected'),
        content: Text('Approve ${ids.length} pending request${ids.length == 1 ? '' : 's'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successGreen),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve All'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isBulkProcessing = true);
    final userId = context.read<UserProvider>().currentUser?.id ?? '';
    final provider = context.read<CommunityProvider>();
    final success = await provider.approveBulkRequests(ids, widget.communityId, userId);
    if (mounted) {
      setState(() {
        _isBulkProcessing = false;
        _selectedIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'Approved ${ids.length} request${ids.length == 1 ? '' : 's'}' : 'Failed to approve'),
        backgroundColor: success ? AppTheme.successGreen : AppTheme.primaryRed,
      ));
    }
  }

  Future<void> _bulkReject(List<CommunityMemberModel> requests) async {
    final ids = _selectedIds.toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Selected'),
        content: Text('Reject ${ids.length} pending request${ids.length == 1 ? '' : 's'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject All', style: TextStyle(color: AppTheme.primaryRed)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isBulkProcessing = true);
    final provider = context.read<CommunityProvider>();
    final success = await provider.rejectBulkRequests(ids);
    if (mounted) {
      setState(() {
        _isBulkProcessing = false;
        _selectedIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'Rejected ${ids.length} request${ids.length == 1 ? '' : 's'}' : 'Failed to reject'),
        backgroundColor: success ? AppTheme.warningOrange : AppTheme.primaryRed,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    final requests = provider.pendingRequests;

    // Only schedule a user fetch when there are IDs not yet requested.
    final hasNew = requests.any((r) => !_requestedIds.contains(r.userId));
    if (hasNew) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadMissingUsers(requests);
      });
    }

    if (provider.isLoading && requests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            Text(
              'No pending requests',
              style: TextStyle(fontSize: 18, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'All join requests have been processed',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    final allSelected = _selectedIds.length == requests.length;

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _users.clear();
          _requestedIds.clear();
          _selectedIds.clear();
        });
        await widget.onRefresh();
      },
      child: Column(
        children: [
          // Select-all header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppTheme.backgroundGrey,
            child: Row(
              children: [
                Checkbox(
                  value: allSelected,
                  tristate: _selectedIds.isNotEmpty && !allSelected,
                  activeColor: AppTheme.primaryRed,
                  onChanged: (_) => setState(() {
                    if (allSelected) {
                      _selectedIds.clear();
                    } else {
                      _selectedIds.addAll(requests.map((r) => r.id));
                    }
                  }),
                ),
                Text(
                  _selectedIds.isEmpty
                      ? 'Select all (${requests.length})'
                      : '${_selectedIds.length} selected',
                  style: AppTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final request = requests[index];
                return _PendingRequestCard(
                  request: request,
                  user: _users[request.userId],
                  communityId: widget.communityId,
                  isSelected: _selectedIds.contains(request.id),
                  onSelectionToggled: (val) => setState(() {
                    val ? _selectedIds.add(request.id) : _selectedIds.remove(request.id);
                  }),
                );
              },
            ),
          ),
          // Bulk action bar
          if (_selectedIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppTheme.cardBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isBulkProcessing ? null : () => _bulkReject(requests),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryRed,
                        side: const BorderSide(color: AppTheme.primaryRed),
                      ),
                      child: _isBulkProcessing
                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text('Reject (${_selectedIds.length})'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isBulkProcessing ? null : () => _bulkApprove(requests),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successGreen),
                      child: _isBulkProcessing
                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('Approve (${_selectedIds.length})'),
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

class _PendingRequestCard extends StatefulWidget {
  final CommunityMemberModel request;
  final String communityId;
  final UserModel? user;
  final bool isSelected;
  final ValueChanged<bool> onSelectionToggled;

  const _PendingRequestCard({
    required this.request,
    required this.communityId,
    required this.user,
    required this.isSelected,
    required this.onSelectionToggled,
  });

  @override
  State<_PendingRequestCard> createState() => _PendingRequestCardState();
}

class _PendingRequestCardState extends State<_PendingRequestCard> {
  bool _isProcessing = false;

  Future<void> _approve() async {
    setState(() => _isProcessing = true);

    final userId = context.read<UserProvider>().currentUser?.id ?? '';
    final provider = context.read<CommunityProvider>();
    final success = await provider.approveRequest(
        widget.request.id, widget.communityId, userId);

    if (mounted) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Request approved' : 'Failed to approve'),
          backgroundColor:
              success ? AppTheme.successGreen : AppTheme.primaryRed,
        ),
      );
    }
  }

  Future<void> _reject() async {
    final provider = context.read<CommunityProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Request'),
        content: const Text('Are you sure you want to reject this request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject',
                style: TextStyle(color: AppTheme.primaryRed)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    final success = await provider.rejectRequest(widget.request.id);

    if (mounted) {
      setState(() => _isProcessing = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(success ? 'Request rejected' : 'Failed to reject'),
          backgroundColor:
              success ? AppTheme.warningOrange : AppTheme.primaryRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return GestureDetector(
      onTap: () => widget.onSelectionToggled(!widget.isSelected),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: widget.isSelected ? AppTheme.primaryRed : AppTheme.cardBorder,
            width: widget.isSelected ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Checkbox(
                    value: widget.isSelected,
                    activeColor: AppTheme.primaryRed,
                    onChanged: (val) => widget.onSelectionToggled(val ?? false),
                  ),
                  const SizedBox(width: 4),
                  UserAvatar(
                    photoUrl: user?.profilePhotoUrl,
                    initials: user?.initials ?? '?',
                    radius: 20,
                    backgroundColor: AppTheme.primaryDark,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? '...',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (user != null)
                          Text(
                            user.handle,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    widget.request.timeAgo,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isProcessing ? null : _reject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryRed,
                        side: const BorderSide(color: AppTheme.primaryRed),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _approve,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successGreen,
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
