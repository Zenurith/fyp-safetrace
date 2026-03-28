import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/models/audit_log_model.dart';
import '../../../data/repositories/audit_log_repository.dart';
import '../../../utils/app_theme.dart';

class AuditLogPage extends StatefulWidget {
  final bool isActive;

  const AuditLogPage({super.key, this.isActive = false});

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  final _repository = AuditLogRepository();
  StreamSubscription? _subscription;

  List<AuditLogModel> _allEntries = [];
  bool _isLoading = false;
  String? _error;

  String _typeFilter = 'all';
  String _dateFilter = 'all';

  static const _typeOptions = [
    ('All types', 'all'),
    ('User', 'user'),
    ('Flag', 'flag'),
    ('Config', 'config'),
    ('Community', 'community'),
    ('Incident', 'incident'),
  ];

  static const _dateOptions = [
    ('All time', 'all'),
    ('Last 7 days', '7d'),
    ('Last 30 days', '30d'),
  ];

  @override
  void initState() {
    super.initState();
    // Don't start listening immediately — wait until the page is actually selected
    // to avoid adding to the concurrent Firestore stream pile at app startup.
    if (widget.isActive) _startListening();
  }

  @override
  void didUpdateWidget(AuditLogPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive && _subscription == null) {
      _startListening();
    }
  }

  void _startListening() {
    _subscription?.cancel();
    _subscription = _repository.watchAll().listen(
      (entries) {
        if (mounted) {
          setState(() {
            _allEntries = entries;
            _isLoading = false;
            _error = null;
          });
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _error = e.toString();
            _isLoading = false;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  List<AuditLogModel> get _filtered {
    final now = DateTime.now();
    return _allEntries.where((e) {
      if (_typeFilter != 'all' && e.targetType != _typeFilter) return false;
      if (_dateFilter == '7d' &&
          now.difference(e.timestamp).inDays > 7) { return false; }
      if (_dateFilter == '30d' &&
          now.difference(e.timestamp).inDays > 30) { return false; }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filters
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _FilterDropdown(
                label: 'Type',
                value: _typeFilter,
                options: _typeOptions,
                onChanged: (v) => setState(() => _typeFilter = v),
              ),
              _FilterDropdown(
                label: 'Date',
                value: _dateFilter,
                options: _dateOptions,
                onChanged: (v) => setState(() => _dateFilter = v),
              ),
              if (!_isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '${entries.length} entr${entries.length == 1 ? 'y' : 'ies'}',
                    style: AppTheme.caption,
                  ),
                ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 48, color: AppTheme.primaryRed),
                          const SizedBox(height: 12),
                          Text(_error!, style: AppTheme.caption),
                          const SizedBox(height: 12),
                          TextButton(
                              onPressed: _startListening,
                              child: const Text('Retry')),
                        ],
                      ),
                    )
                  : entries.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history,
                                  size: 64, color: AppTheme.cardBorder),
                              const SizedBox(height: 16),
                              Text('No audit entries yet',
                                  style: AppTheme.bodyLarge.copyWith(
                                      color: AppTheme.textSecondary)),
                              const SizedBox(height: 8),
                              Text(
                                  'Admin actions will appear here as they happen.',
                                  style: AppTheme.caption),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          itemCount: entries.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) =>
                              _AuditEntryCard(entry: entries[i]),
                        ),
        ),
      ],
    );
  }
}

class _AuditEntryCard extends StatelessWidget {
  final AuditLogModel entry;
  const _AuditEntryCard({required this.entry});

  Color get _typeColor {
    switch (entry.targetType) {
      case 'user':
        return AppTheme.primaryRed;
      case 'flag':
        return AppTheme.warningOrange;
      case 'config':
        return AppTheme.accentBlue;
      case 'community':
        return AppTheme.successGreen;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type indicator
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _typeIconFor(entry.targetType),
              size: 18,
              color: _typeColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(entry.action,
                          style: AppTheme.bodyMedium
                              .copyWith(fontWeight: FontWeight.w700)),
                    ),
                    Text(entry.timeAgo, style: AppTheme.caption),
                  ],
                ),
                const SizedBox(height: 2),
                if (entry.detail.isNotEmpty)
                  Text(
                    entry.detail,
                    style: AppTheme.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _typeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        entry.targetType.toUpperCase(),
                        style: TextStyle(
                            fontSize: 9,
                            color: _typeColor,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('by ${entry.adminName}', style: AppTheme.caption),
                    const Spacer(),
                    Text(entry.formattedTime,
                        style: AppTheme.caption
                            .copyWith(fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _typeIconFor(String type) {
    switch (type) {
      case 'user':
        return Icons.person_outline;
      case 'flag':
        return Icons.flag_outlined;
      case 'config':
        return Icons.tune_outlined;
      case 'community':
        return Icons.groups_outlined;
      case 'incident':
        return Icons.warning_amber_outlined;
      default:
        return Icons.info_outline;
    }
  }
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          style: AppTheme.bodyMedium,
          items: options
              .map((opt) => DropdownMenuItem(
                    value: opt.$2,
                    child: Text(opt.$1),
                  ))
              .toList(),
          onChanged: (v) => v != null ? onChanged(v) : null,
        ),
      ),
    );
  }
}
