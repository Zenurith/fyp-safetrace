import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/share_utils.dart';
import '../../data/models/flag_model.dart';
import '../../data/models/incident_model.dart';
import '../../data/repositories/incident_repository.dart';
import '../../utils/app_theme.dart';
import '../providers/incident_provider.dart';
import '../providers/user_provider.dart';
import 'comments_section.dart';
import 'flag_dialog.dart';
import 'photo_gallery_viewer.dart';
import 'status_timeline_widget.dart';
import 'vote_buttons.dart';

class IncidentBottomSheet extends StatefulWidget {
  final String incidentId;
  final VoidCallback? onViewOnMap;

  const IncidentBottomSheet({super.key, required this.incidentId, this.onViewOnMap});

  @override
  State<IncidentBottomSheet> createState() => _IncidentBottomSheetState();
}

class _IncidentBottomSheetState extends State<IncidentBottomSheet> {
  final _repository = IncidentRepository();
  IncidentModel? _fetched;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchIfNeeded());
  }

  Future<void> _fetchIfNeeded() async {
    if (!mounted) return;
    final provider = context.read<IncidentProvider>();
    final inProvider = provider.incidents.where((i) => i.id == widget.incidentId).firstOrNull
        ?? provider.myReports.where((i) => i.id == widget.incidentId).firstOrNull;
    if (inProvider != null) return; // already loaded, build() will pick it up

    setState(() => _loading = true);
    final incident = await _repository.getById(widget.incidentId);
    if (!mounted) return;
    setState(() {
      _fetched = incident;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch the incident from the provider to get real-time updates.
    // Falls back to myReports, then to a direct Firestore fetch (_fetched)
    // for cold-start notification taps where the provider isn't loaded yet.
    final provider = context.watch<IncidentProvider>();
    final incident = provider.incidents.where((i) => i.id == widget.incidentId).firstOrNull
        ?? provider.myReports.where((i) => i.id == widget.incidentId).firstOrNull
        ?? _fetched;

    final sheetDecoration = BoxDecoration(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
    );

    if (_loading) {
      return Container(
        height: 120,
        decoration: sheetDecoration,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (incident == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: sheetDecoration,
        child: const Center(
          child: Text('Incident not found'),
        ),
      );
    }

    return Container(
      decoration: sheetDecoration,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20, 20, 20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Handle bar
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

          // Header row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.categoryColor(incident.categoryLabel)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.categoryColor(incident.categoryLabel),
                    ),
                  ),
                  child: Text(
                    '${incident.categoryLabel} - ${incident.title}',
                    style: TextStyle(
                      color: AppTheme.categoryColor(incident.categoryLabel),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppTheme.severityColor(incident.severityLabel),
                  shape: BoxShape.circle,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Status and time row
          Row(
            children: [
              _StatusBadge(status: incident.status),
              const SizedBox(width: 8),
              Text(
                'Reported ${incident.timeAgo}',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            ],
          ),

          // Image verification badge (for admins)
          if (incident.verificationScore != null) ...[
            const SizedBox(height: 8),
            _ImageVerificationBadge(incident: incident),
          ],
          const SizedBox(height: 16),

          // Location
          const Text(
            'Location',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryRed),
          ),
          const SizedBox(height: 4),
          Text(
            incident.address,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),

          // Description
          const Text(
            'Description',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryRed),
          ),
          const SizedBox(height: 4),
          Text(
            incident.description,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),

          // Media
          if (incident.mediaUrls.isNotEmpty) ...[
            Row(
              children: [
                const Text(
                  'Media',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryDark),
                ),
                const SizedBox(width: 8),
                Text(
                  '${incident.mediaUrls.length} ${incident.mediaUrls.length == 1 ? 'photo' : 'photos'}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: incident.mediaUrls.length,
                itemBuilder: (context, index) {
                  final url = incident.mediaUrls[index];
                  final isVideo = url.contains('/videos/') ||
                      url.toLowerCase().endsWith('.mp4') ||
                      url.toLowerCase().endsWith('.mov');
                  final isLocalFile = url.startsWith('/') || url.startsWith('file://');

                  return GestureDetector(
                    onTap: () => PhotoGalleryViewer.show(
                      context,
                      incident.mediaUrls,
                      initialIndex: index,
                    ),
                    child: Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: isVideo ? Colors.grey[800] : Colors.grey[200],
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: isVideo
                              ? const Icon(Icons.play_circle_outline,
                                  color: Colors.white, size: 32)
                              : isLocalFile
                                  ? Image.file(
                                      File(url.replaceFirst('file://', '')),
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Icon(Icons.broken_image,
                                            color: Colors.grey);
                                      },
                                    )
                                  : Image.network(
                                      url,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, progress) {
                                        if (progress == null) return child;
                                        return const Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Icon(Icons.broken_image,
                                            color: Colors.grey);
                                      },
                                    ),
                        ),
                        // Photo number indicator
                        if (incident.mediaUrls.length > 1)
                          Positioned(
                            bottom: 4,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${index + 1}/${incident.mediaUrls.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Status Timeline
          StatusTimelineWidget(incident: incident),
          const SizedBox(height: 16),

          // Voting section
          _VotingSection(incident: incident),
          const SizedBox(height: 16),

          // Comments section
          CommentsSection(
            incidentId: incident.id,
            communityId: incident.communityIds.isNotEmpty
                ? incident.communityIds.first
                : null,
          ),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (widget.onViewOnMap != null) {
                      widget.onViewOnMap!();
                    } else {
                      context.read<IncidentProvider>().requestMapFocus(incident);
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('View on Map'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryRed,
                    side: const BorderSide(color: AppTheme.primaryRed),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showShareOptions(context, incident),
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
          // Report button — only shown for incidents reported by others
          if (context.read<UserProvider>().currentUser?.id != incident.reporterId)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => FlagDialog.show(
                  context,
                  targetType: FlagTargetType.incident,
                  targetId: incident.id,
                  communityId: incident.communityIds.isNotEmpty
                      ? incident.communityIds.first
                      : null,
                ),
                icon: const Icon(Icons.flag_outlined, size: 16),
                label: const Text('Report'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  textStyle: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
    );
  }

}


class _VotingSection extends StatelessWidget {
  final IncidentModel incident;

  const _VotingSection({required this.incident});

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<UserProvider>().currentUser;
    final isOwnReport = currentUser?.id == incident.reporterId;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundGrey,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Community Feedback',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryDark,
                ),
              ),
              const Spacer(),
              if (isOwnReport)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Your report',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              VoteButtons(incident: incident),
              const Spacer(),
              if (incident.confirmations > 0)
                Row(
                  children: [
                    const Icon(Icons.verified, color: AppTheme.successGreen, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${incident.confirmations} confirmed',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.successGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final IncidentStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _getStatusColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _getStatusColor().withValues(alpha: 0.5)),
      ),
      child: Text(
        _getStatusLabel(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _getStatusColor(),
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (status) {
      case IncidentStatus.pending:
        return AppTheme.warningOrange;
      case IncidentStatus.underReview:
        return AppTheme.accentBlue;
      case IncidentStatus.verified:
        return AppTheme.successGreen;
      case IncidentStatus.resolved:
        return AppTheme.primaryDark;
      case IncidentStatus.dismissed:
        return AppTheme.textSecondary;
    }
  }

  String _getStatusLabel() {
    switch (status) {
      case IncidentStatus.pending:
        return 'Pending';
      case IncidentStatus.underReview:
        return 'Under Review';
      case IncidentStatus.verified:
        return 'Verified';
      case IncidentStatus.resolved:
        return 'Resolved';
      case IncidentStatus.dismissed:
        return 'Dismissed';
    }
  }
}

class _ImageVerificationBadge extends StatelessWidget {
  final IncidentModel incident;

  const _ImageVerificationBadge({required this.incident});

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<UserProvider>().currentUser;
    final isAdmin = currentUser?.isAdmin ?? false;
    final score = incident.verificationScore ?? 0;
    final needsReview = incident.needsImageReview;

    // Only show detailed info to admins, but show basic verification to all
    final color = _getVerificationColor(score);
    final icon = needsReview ? Icons.warning_amber_rounded : Icons.verified_outlined;

    return GestureDetector(
      onTap: isAdmin && incident.verificationNote != null
          ? () => _showVerificationDetails(context)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              needsReview ? 'Needs Review' : 'Image Verified',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
            if (isAdmin) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${(score * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.info_outline, size: 12, color: color),
            ],
          ],
        ),
      ),
    );
  }

  Color _getVerificationColor(double score) {
    if (score >= 0.7) return AppTheme.successGreen;
    if (score >= 0.4) return AppTheme.warningOrange;
    return AppTheme.primaryRed;
  }

  void _showVerificationDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.image_search, color: AppTheme.primaryDark),
            SizedBox(width: 8),
            Text('Image Verification'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Status', incident.imageVerified == true ? 'Valid' : 'Flagged'),
            _buildDetailRow('Confidence', '${((incident.verificationScore ?? 0) * 100).toInt()}% (${incident.verificationLabel ?? "N/A"})'),
            const SizedBox(height: 12),
            const Text(
              'AI Analysis:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              incident.verificationNote ?? 'No details available',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
