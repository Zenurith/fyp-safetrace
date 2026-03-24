import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../repositories/user_repository.dart';

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final UserRepository _userRepository = UserRepository();

  bool _isInitialized = false;
  GlobalKey<NavigatorState>? _navigatorKey;

  /// Callback set by the presentation layer to handle incident navigation.
  /// Receives the navigator context and the incidentId from the notification.
  void Function(BuildContext context, String incidentId)? _onIncidentTap;

  /// Callback set by the presentation layer to handle community navigation.
  void Function(BuildContext context, String communityId)? _onCommunityTap;

  /// Set the navigator key for context access from notification taps.
  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  /// Set the callback that the presentation layer uses to navigate to an incident.
  void setOnIncidentTap(void Function(BuildContext context, String incidentId) callback) {
    _onIncidentTap = callback;
  }

  /// Set the callback that the presentation layer uses to navigate to a community.
  void setOnCommunityTap(void Function(BuildContext context, String communityId) callback) {
    _onCommunityTap = callback;
  }

  Future<void> initialize(String? userId) async {
    if (_isInitialized) return;

    // Request permission
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      return;
    }

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Get and save FCM token
    if (userId != null) {
      await _saveToken(userId);
    }

    // Listen for token refresh
    _fcm.onTokenRefresh.listen((token) {
      if (userId != null) {
        _userRepository.updateFcmToken(userId, token);
      }
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background/terminated messages
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Handle cold start: app launched by tapping a notification while terminated
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _routeMessage(initialMessage.data);
      });
    }

    _isInitialized = true;
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'safetrace_incidents',
        'Incident Alerts',
        description: 'Notifications for nearby incidents',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  Future<void> _saveToken(String userId) async {
    final token = await _fcm.getToken();
    if (token != null) {
      await _userRepository.updateFcmToken(userId, token);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    // Encode type into payload so _onNotificationTap can route correctly
    final type = message.data['type'];
    String? payload;
    if (type == 'community_post') {
      final communityId = message.data['communityId'];
      if (communityId != null) payload = 'community:$communityId';
    } else {
      final incidentId = message.data['incidentId'];
      if (incidentId != null) payload = 'incident:$incidentId';
    }

    _showLocalNotification(
      title: notification.title ?? 'SafeTrace',
      body: notification.body ?? '',
      payload: payload,
    );
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    _routeMessage(message.data);
  }

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;
    if (payload.startsWith('community:')) {
      _navigateToCommunity(payload.substring('community:'.length));
    } else if (payload.startsWith('incident:')) {
      _navigateToIncident(payload.substring('incident:'.length));
    } else {
      // Legacy: bare incidentId (no prefix)
      _navigateToIncident(payload);
    }
  }

  /// Route a notification data payload to the correct screen.
  void _routeMessage(Map<String, dynamic> data) {
    final type = data['type'];
    if (type == 'community_post') {
      final communityId = data['communityId'];
      if (communityId != null) _navigateToCommunity(communityId);
    } else {
      final incidentId = data['incidentId'];
      if (incidentId != null) _navigateToIncident(incidentId);
    }
  }

  void _navigateToIncident(String incidentId) {
    final context = _navigatorKey?.currentContext;
    if (context == null) return;
    _onIncidentTap?.call(context, incidentId);
  }

  void _navigateToCommunity(String communityId) {
    final context = _navigatorKey?.currentContext;
    if (context == null) return;
    _onCommunityTap?.call(context, communityId);
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'safetrace_incidents',
      'Incident Alerts',
      channelDescription: 'Notifications for nearby incidents',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Show a notification for a nearby incident
  Future<void> showIncidentNotification({
    required String incidentId,
    required String title,
    required String category,
    required double distanceKm,
  }) async {
    await _showLocalNotification(
      title: title.isNotEmpty ? title : '$category Alert',
      body: '$category • ${distanceKm.toStringAsFixed(1)}km away',
      payload: incidentId,
    );
  }

  /// Remove FCM token when user logs out
  Future<void> clearToken(String userId) async {
    await _userRepository.updateFcmToken(userId, null);
    await _fcm.deleteToken();
  }
}

/// Background message handler - must be a top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // FCM automatically shows the notification in the system tray when the app
  // is in background/terminated, as long as the message contains a
  // 'notification' payload (which our Cloud Function sends).
  // No additional handling needed here.
}
