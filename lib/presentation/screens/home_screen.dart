import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/incident_model.dart';
import '../../data/services/incident_notification_service.dart';
import '../../data/services/location_service.dart';
import '../providers/user_provider.dart';
import '../providers/incident_provider.dart';
import '../providers/vote_provider.dart';
import '../providers/alert_settings_provider.dart';
import '../widgets/incident_bottom_sheet.dart';
import '../widgets/incident_notification_overlay.dart';
import 'map_screen.dart';
import 'my_reports_screen.dart';
import 'alert_settings_screen.dart';
import 'admin_screen.dart';
import 'profile_screen.dart';
import 'community_list_screen.dart';

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

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().currentUser;
    final isAdmin = user?.isAdmin ?? false;

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

    final screens = [
      const MapScreen(),
      const CommunityListScreen(),
      const MyReportsScreen(),
      const AlertSettingsScreen(),
      if (isAdmin) const AdminScreen(),
      const ProfileScreen(),
    ];

    // Reset index if it's out of bounds (e.g. role changed)
    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }

    final navItems = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.map),
        label: 'Map',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.groups),
        label: 'Communities',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.history),
        label: 'My Reports',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.warning_amber_rounded),
        label: 'Alerts',
      ),
      if (isAdmin)
        const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings),
          label: 'Admin',
        ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person),
        label: 'Profile',
      ),
    ];

    return Scaffold(
      body: Stack(
        children: [
          // Main content
          Scaffold(
            body: screens[_currentIndex],
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
              selectedItemColor: const Color(0xFFE53E3E),
              unselectedItemColor: Colors.grey,
              type: BottomNavigationBarType.fixed,
              items: navItems,
            ),
          ),
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
    );
  }
}
