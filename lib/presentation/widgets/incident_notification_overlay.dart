import 'package:flutter/material.dart';
import '../../data/models/incident_model.dart';

class IncidentNotificationOverlay extends StatefulWidget {
  final IncidentModel incident;
  final double distance;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const IncidentNotificationOverlay({
    super.key,
    required this.incident,
    required this.distance,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<IncidentNotificationOverlay> createState() =>
      _IncidentNotificationOverlayState();
}

class _IncidentNotificationOverlayState
    extends State<IncidentNotificationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    _controller.forward();

    // Auto dismiss after 8 seconds
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) {
        _dismissWithAnimation();
      }
    });
  }

  void _dismissWithAnimation() {
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData _getCategoryIcon() {
    switch (widget.incident.category) {
      case IncidentCategory.crime:
        return Icons.warning;
      case IncidentCategory.infrastructure:
        return Icons.build;
      case IncidentCategory.suspicious:
        return Icons.visibility;
      case IncidentCategory.traffic:
        return Icons.traffic;
      case IncidentCategory.environmental:
        return Icons.eco;
      case IncidentCategory.emergency:
        return Icons.emergency;
    }
  }

  Color _getSeverityColor() {
    switch (widget.incident.severity) {
      case SeverityLevel.low:
        return Colors.orange;
      case SeverityLevel.moderate:
        return Colors.deepOrange;
      case SeverityLevel.high:
        return Colors.red;
    }
  }

  String _formatDistance() {
    if (widget.distance < 1) {
      return '${(widget.distance * 1000).round()} m away';
    }
    return '${widget.distance.toStringAsFixed(1)} km away';
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: _getSeverityColor(),
            child: InkWell(
              onTap: () {
                _controller.reverse().then((_) => widget.onTap());
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getCategoryIcon(),
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'New ${widget.incident.categoryLabel} Alert',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.incident.title,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDistance(),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: _dismissWithAnimation,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
