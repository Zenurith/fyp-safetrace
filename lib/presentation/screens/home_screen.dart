import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/incident_model.dart';
import '../../data/services/incident_notification_service.dart';
import '../../data/services/location_service.dart';
import '../../utils/app_theme.dart';
import '../providers/user_provider.dart';
import '../providers/incident_provider.dart';
import '../providers/vote_provider.dart';
import '../providers/alert_settings_provider.dart';
import '../widgets/incident_bottom_sheet.dart';
import '../widgets/incident_notification_overlay.dart';
import 'map_screen.dart';
import 'alert_settings_screen.dart';
import 'profile_screen.dart';
import 'community_list_screen.dart';
import 'report_incident_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _votesLoaded = false;

  final _notificationService = IncidentNotificationService();
  final _locationService = LocationService();
  StreamSubscription? _notificationSubscription;

  // Current notification to display
  IncidentNotification? _currentNotification;

  // Track previous incident count to detect new ones
  int _previousIncidentCount = 0;

  @override
  void initState() {
    super.initState();
    // Start listening to incidents when home screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IncidentProvider>().startListening();
      _loadUserVotesIfNeeded();
      _initNotifications();
    });
  }

  void _initNotifications() {
    // Listen for notification events
    _notificationSubscription =
        _notificationService.notificationStream.listen((notification) {
      if (mounted) {
        setState(() {
          _currentNotification = notification;
        });
      }
    });

    // Get location immediately
    _updateUserLocation();
  }

  Future<void> _updateUserLocation() async {
    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        _notificationService.updateUserLocation(
          position.latitude,
          position.longitude,
        );
        // Check incidents immediately after getting location
        if (mounted) {
          _checkForNewIncidents();
        }
      }
    } catch (e) {
      debugPrint('Failed to update location: $e');
    }
  }

  void _checkForNewIncidents() {
    if (!mounted) return;

    final incidents = context.read<IncidentProvider>().incidents;
    final settings = context.read<AlertSettingsProvider>().settings;
    final userId = context.read<UserProvider>().currentUser?.id;

    _notificationService.checkNewIncidents(
      incidents: incidents,
      settings: settings,
      currentUserId: userId,
    );
  }

  void _loadUserVotesIfNeeded() {
    if (_votesLoaded) return;
    final user = context.read<UserProvider>().currentUser;
    if (user != null) {
      context.read<VoteProvider>().loadUserVotes(user.id);
      _votesLoaded = true;
    }
  }

  void _showIncidentDetails(IncidentModel incident) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => IncidentBottomSheet(incidentId: incident.id),
    );
  }

  void _openReportScreen() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const ReportIncidentScreen(),
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incident reported successfully!'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().currentUser;

    // Watch for incident changes and check for new incidents immediately
    final incidents = context.watch<IncidentProvider>().incidents;

    // Detect new incidents and check immediately
    if (incidents.length > _previousIncidentCount && _previousIncidentCount > 0) {
      // New incident added - check immediately
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkForNewIncidents();
      });
    }
    _previousIncidentCount = incidents.length;

    // Load user votes once user is available
    if (user != null && !_votesLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadUserVotesIfNeeded();
      });
    }

    // Index mapping: 0=Map, 1=Community, 2=Add (action), 3=Alerts, 4=Profile
    Widget currentScreen;
    switch (_currentIndex) {
      case 0:
        currentScreen = const MapScreen();
        break;
      case 1:
        currentScreen = const CommunityListScreen();
        break;
      case 3:
        currentScreen = const AlertSettingsScreen();
        break;
      case 4:
        currentScreen = const ProfileScreen();
        break;
      default:
        currentScreen = const MapScreen();
    }

    return Scaffold(
      body: Stack(
        children: [
          // Main content
          currentScreen,
          // Notification overlay
          if (_currentNotification != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Material(
                color: Colors.transparent,
                child: IncidentNotificationOverlay(
                  incident: _currentNotification!.incident,
                  distance: _currentNotification!.distance,
                  onTap: () {
                    final incident = _currentNotification!.incident;
                    setState(() => _currentNotification = null);
                    _showIncidentDetails(incident);
                  },
                  onDismiss: () {
                    setState(() => _currentNotification = null);
                  },
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: AppTheme.cardBorder, width: 1),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Map
                _NavItem(
                  iconPath: 'assets/icon/map.png',
                  label: 'Map',
                  isSelected: _currentIndex == 0,
                  onTap: () => setState(() => _currentIndex = 0),
                ),
                // Community
                _NavItem(
                  iconPath: 'assets/icon/community.png',
                  label: 'Community',
                  isSelected: _currentIndex == 1,
                  onTap: () => setState(() => _currentIndex = 1),
                ),
                // Add button (red circle)
                GestureDetector(
                  onTap: _openReportScreen,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryRed,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                // Alerts
                _NavItem(
                  iconPath: 'assets/icon/warning.png',
                  label: 'Alerts',
                  isSelected: _currentIndex == 3,
                  onTap: () => setState(() => _currentIndex = 3),
                ),
                // Profile
                _NavItem(
                  iconPath: 'assets/icon/user.png',
                  label: 'Profile',
                  isSelected: _currentIndex == 4,
                  onTap: () => setState(() => _currentIndex = 4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String iconPath;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.iconPath,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppTheme.primaryRed : AppTheme.textSecondary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ImageIcon(
            AssetImage(iconPath),
            size: 24,
            color: color,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
