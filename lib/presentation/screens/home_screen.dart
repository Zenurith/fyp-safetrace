import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/incident_model.dart';
import '../../data/services/incident_notification_service.dart';
import '../../data/services/location_service.dart';
import '../../utils/app_theme.dart';
import '../providers/user_provider.dart';
import '../providers/incident_provider.dart';
import '../providers/vote_provider.dart';
import '../providers/alert_settings_provider.dart';
import '../providers/community_provider.dart';
import '../providers/system_config_provider.dart';
import '../widgets/incident_bottom_sheet.dart';
import '../widgets/incident_notification_overlay.dart';
import 'map_screen.dart';
import 'alert_settings_screen.dart';
import 'profile_screen.dart';
import 'community_list_screen.dart';
import 'report_incident_screen.dart';
import 'notification_history_screen.dart';

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
  late final IncidentProvider _incidentProvider;

  // Current notification to display
  IncidentNotification? _currentNotification;

  // Track previous incident count to detect new ones
  int _previousIncidentCount = 0;

  @override
  void initState() {
    super.initState();
    _incidentProvider = context.read<IncidentProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _incidentProvider.startListening();
      context.read<SystemConfigProvider>().startListening();
      _loadUserVotesIfNeeded();
      _initNotifications();
      _wireUpAlertSettings();
      _incidentProvider.addListener(_onIncidentProviderChanged);
    });
  }

  void _onIncidentProviderChanged() {
    final provider = _incidentProvider;
    if (provider.mapTabRequested) {
      provider.acknowledgeMapTabRequest();
      if (mounted) setState(() => _currentIndex = 0);
    }
    // Detect new incidents and trigger proximity check
    final count = provider.incidents.length;
    if (count > _previousIncidentCount && _previousIncidentCount > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkForNewIncidents();
      });
    }
    _previousIncidentCount = count;
  }

  void _initNotifications() {
    // Listen for notification events
    _notificationSubscription =
        _notificationService.notificationStream.listen((notification) {
      if (mounted) {
        _saveToHistory(notification);
        setState(() {
          _currentNotification = notification;
        });
      }
    });

    // Get location immediately
    _updateUserLocation();
  }

  Future<void> _wireUpAlertSettings() async {
    final userId = context.read<UserProvider>().currentUser?.id;
    if (userId != null) {
      await context.read<AlertSettingsProvider>().setUserId(userId);
    }
  }

  Future<void> _updateUserLocation() async {
    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        _notificationService.updateUserLocation(
          position.latitude,
          position.longitude,
        );
        // Save location to Firestore so Cloud Function can use it
        if (mounted) {
          context.read<UserProvider>().updateLocation(
            position.latitude,
            position.longitude,
          );
          _checkForNewIncidents();
        }
      }
    } catch (e) {
      debugPrint('Failed to update location: $e');
    }
  }

  void _checkForNewIncidents() {
    if (!mounted) return;

    final allIncidents = context.read<IncidentProvider>().incidents;
    final myMembershipIds =
        context.read<CommunityProvider>().myMembershipCommunityIds;
    // Only notify for public incidents or community incidents the user belongs to
    final incidents = allIncidents
        .where((i) =>
            i.communityIds.isEmpty ||
            i.communityIds.any((id) => myMembershipIds.contains(id)))
        .toList();
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

  /// Saves a notification to SharedPreferences history.
  Future<void> _saveToHistory(IncidentNotification n) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList('notification_history') ?? [];
      final entry = jsonEncode({
        'incidentId': n.incident.id,
        'title': n.incident.title,
        'category': n.incident.categoryLabel,
        'distance': n.distance,
        'timestamp': DateTime.now().toIso8601String(),
      });
      existing.add(entry);
      // Keep at most 100 entries
      final trimmed = existing.length > 100
          ? existing.sublist(existing.length - 100)
          : existing;
      await prefs.setStringList('notification_history', trimmed);
    } catch (e) {
      debugPrint('Failed to save notification history: $e');
    }
  }

  /// Dequeues the next notification from the service and shows it.
  void _dequeueNextNotification() {
    final next = _notificationService.dequeueNext();
    if (next != null && mounted) {
      _saveToHistory(next);
      setState(() {
        _currentNotification = next;
      });
    }
  }

  void _showIncidentDetails(IncidentModel incident) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => IncidentBottomSheet(
        incidentId: incident.id,
        onViewOnMap: () {
          Navigator.pop(context);
          context.read<IncidentProvider>().selectIncident(incident);
          setState(() => _currentIndex = 0);
        },
      ),
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

  void _openNotificationHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NotificationHistoryScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _incidentProvider.removeListener(_onIncidentProviderChanged);
    _notificationSubscription?.cancel();
    _notificationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only rebuild when user presence changes (null ↔ non-null), not on every profile update
    final userIsLoaded = context.select<UserProvider, bool>((p) => p.currentUser != null);

    // Load user votes once user is available (first time only)
    if (userIsLoaded && !_votesLoaded) {
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
        currentScreen = AlertSettingsScreen(
          onSaved: () => setState(() => _currentIndex = 0),
        );
        break;
      case 4:
        currentScreen = ProfileScreen(
          onSwitchTab: (index) => setState(() => _currentIndex = index),
        );
        break;
      default:
        currentScreen = const MapScreen();
    }

    return Scaffold(
      appBar: _currentIndex == 0
          ? AppBar(
              backgroundColor: AppTheme.primaryDark,
              foregroundColor: Colors.white,
              title: const Text(
                'SafeTrace',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_none_outlined,
                      color: Colors.white),
                  tooltip: 'Notification History',
                  onPressed: _openNotificationHistory,
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          const _AnnouncementBannerSlot(),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
          // Main content
          currentScreen,
          // Notification overlay
          if (_currentNotification != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IncidentNotificationOverlay(
                  incident: _currentNotification!.incident,
                  distance: _currentNotification!.distance,
                  onTap: () {
                    final incident = _currentNotification!.incident;
                    setState(() => _currentNotification = null);
                    _dequeueNextNotification();
                    _showIncidentDetails(incident);
                  },
                  onDismiss: () {
                    setState(() => _currentNotification = null);
                    _dequeueNextNotification();
                  },
                ),
            ),
              ],
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
                    width: 46,
                    height: 46,
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

/// Watches SystemConfigProvider in isolation so only this widget rebuilds on config changes.
class _AnnouncementBannerSlot extends StatelessWidget {
  const _AnnouncementBannerSlot();

  @override
  Widget build(BuildContext context) {
    final sysConfig = context.watch<SystemConfigProvider>().config;
    if (!sysConfig.announcementEnabled || sysConfig.announcementMessage.isEmpty) {
      return const SizedBox.shrink();
    }
    return _AnnouncementBanner(message: sysConfig.announcementMessage);
  }
}

class _AnnouncementBanner extends StatelessWidget {
  final String message;

  const _AnnouncementBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.primaryDark,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.campaign_outlined, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
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
