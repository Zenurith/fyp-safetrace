import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/incident_model.dart';
import '../../utils/app_theme.dart';
import '../providers/incident_provider.dart';
import '../widgets/incident_bottom_sheet.dart';

class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  State<NotificationHistoryScreen> createState() =>
      _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState
    extends State<NotificationHistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('notification_history') ?? [];
    final parsed = raw
        .map((e) {
          try {
            return jsonDecode(e) as Map<String, dynamic>;
          } catch (_) {
            return null;
          }
        })
        .whereType<Map<String, dynamic>>()
        .toList();
    // Most recent first
    parsed.sort((a, b) {
      final ta = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime(0);
      final tb = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime(0);
      return tb.compareTo(ta);
    });
    if (mounted) {
      setState(() {
        _history = parsed;
        _loading = false;
      });
    }
  }

  void _showIncidentDetails(BuildContext context, String incidentId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => IncidentBottomSheet(
        incidentId: incidentId,
        onViewOnMap: () {
          Navigator.pop(context); // close bottom sheet
          Navigator.pop(context); // go back to home / map
          final provider = context.read<IncidentProvider>();
          final incident = provider.incidents
              .where((i) => i.id == incidentId)
              .firstOrNull;
          if (incident != null) {
            provider.selectIncident(incident);
          }
        },
      ),
    );
  }

  String _timeAgo(String? isoTimestamp) {
    if (isoTimestamp == null) return '';
    final dt = DateTime.tryParse(isoTimestamp);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  IconData _categoryIcon(String? category) {
    switch ((category ?? '').toLowerCase()) {
      case 'crime':
        return Icons.shield_outlined;
      case 'traffic':
        return Icons.traffic_outlined;
      case 'emergency':
        return Icons.local_fire_department_outlined;
      case 'infrastructure':
        return Icons.construction_outlined;
      case 'environmental':
        return Icons.eco_outlined;
      case 'suspicious':
        return Icons.visibility_outlined;
      default:
        return Icons.warning_amber_outlined;
    }
  }

  Color _categoryColor(String? category) {
    return AppTheme.categoryColor(category ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification History'),
      ),
      backgroundColor: AppTheme.backgroundGrey,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.notifications_none_outlined,
                        size: 56,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No notifications yet',
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  itemCount: _history.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final entry = _history[index];
                    final category = entry['category'] as String?;
                    final color = _categoryColor(category);
                    return GestureDetector(
                      onTap: () {
                        final id = entry['incidentId'] as String?;
                        if (id != null) {
                          _showIncidentDetails(context, id);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: AppTheme.cardDecoration,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Category icon
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: color.withValues(alpha: 0.3)),
                              ),
                              child: Icon(
                                _categoryIcon(category),
                                color: color,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry['title'] ?? 'Incident',
                                    style: AppTheme.headingSmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        category ?? '',
                                        style: AppTheme.caption.copyWith(
                                          color: color,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (entry['distance'] != null) ...[
                                        Text(
                                          '  \u00b7  ',
                                          style: AppTheme.caption,
                                        ),
                                        Text(
                                          '${(entry['distance'] as num).toStringAsFixed(1)} km away',
                                          style: AppTheme.caption,
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _timeAgo(entry['timestamp']),
                              style: AppTheme.caption,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
