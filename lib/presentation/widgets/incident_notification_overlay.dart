import 'package:flutter/material.dart';
import '../../data/models/incident_model.dart';
import '../../utils/app_theme.dart';

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

  String _getCategoryIconPath() {
    switch (widget.incident.category) {
      case IncidentCategory.crime:
        return 'assets/icon/warning.png';
      case IncidentCategory.suspicious:
        return 'assets/icon/eye.png';
      case IncidentCategory.traffic:
        return 'assets/icon/warning.png';
      case IncidentCategory.infrastructure:
        return 'assets/icon/report.png';
      case IncidentCategory.environmental:
        return 'assets/icon/warning.png';
      case IncidentCategory.emergency:
        return 'assets/icon/warning.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: SafeArea(
        bottom: false,
        child: GestureDetector(
          onTap: () {
            _controller.reverse().then((_) => widget.onTap());
          },
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.warningOrange,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Category icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: ImageIcon(
                      AssetImage(_getCategoryIconPath()),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Title and category tag
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'New ${widget.incident.categoryLabel} Alert',
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.incident.categoryLabel.toLowerCase(),
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w400,
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Dismiss button
                GestureDetector(
                  onTap: _dismissWithAnimation,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
