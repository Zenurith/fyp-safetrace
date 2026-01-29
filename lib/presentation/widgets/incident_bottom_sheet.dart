import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/models/incident_model.dart';
import '../../utils/app_theme.dart';

class IncidentBottomSheet extends StatelessWidget {
  final IncidentModel incident;

  const IncidentBottomSheet({super.key, required this.incident});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
              Container(
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
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Reported ${incident.timeAgo}',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
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
            const Text(
              'Media',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryDark),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: incident.mediaUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final url = incident.mediaUrls[index];
                  final isVideo = url.endsWith('.mp4') || url.endsWith('.mov');
                  return GestureDetector(
                    onTap: () => _showMediaViewer(context, url, isVideo),
                    child: _MediaThumbnail(url: url, isVideo: isVideo),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Confirmations
          if (incident.confirmations > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: AppTheme.successGreen, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '${incident.confirmations} community members confirmed this',
                    style: const TextStyle(
                      color: AppTheme.successGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryRed,
                    side: const BorderSide(color: AppTheme.primaryRed),
                  ),
                  child: const Text('View on Map'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  child: const Text('Share'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  child: const Text('Report'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

void _showMediaViewer(BuildContext context, String url, bool isVideo) {
  final isNetworkUrl = url.startsWith('http');

  if (isVideo) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Video playback not yet implemented')),
    );
    return;
  }

  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: isNetworkUrl
                  ? Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _buildErrorWidget(),
                    )
                  : Image.file(
                      File(url),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _buildErrorWidget(),
                    ),
            ),
          ),
          Positioned(
            top: 40,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildErrorWidget() {
  return Container(
    width: 200,
    height: 200,
    color: Colors.grey[300],
    child: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image, size: 48, color: Colors.grey),
          SizedBox(height: 8),
          Text('Image not available', style: TextStyle(color: Colors.grey)),
        ],
      ),
    ),
  );
}

class _MediaThumbnail extends StatelessWidget {
  final String url;
  final bool isVideo;

  const _MediaThumbnail({required this.url, required this.isVideo});

  @override
  Widget build(BuildContext context) {
    final isNetworkUrl = url.startsWith('http');

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isVideo)
            Container(
              color: Colors.grey[300],
              child: const Icon(Icons.videocam, color: Colors.grey, size: 40),
            )
          else if (isNetworkUrl)
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image,
                color: Colors.grey,
                size: 40,
              ),
            )
          else
            Image.file(
              File(url),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image,
                color: Colors.grey,
                size: 40,
              ),
            ),
          if (isVideo)
            const Center(
              child: Icon(
                Icons.play_circle_fill,
                color: Colors.white70,
                size: 36,
              ),
            ),
        ],
      ),
    );
  }
}
