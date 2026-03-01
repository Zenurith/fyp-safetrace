import 'dart:io';
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

    // Show local notification
    _showLocalNotification(
      title: notification.title ?? 'SafeTrace',
      body: notification.body ?? '',
      payload: message.data['incidentId'],
    );
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    // Handle notification tap when app was in background
    final incidentId = message.data['incidentId'];
    if (incidentId != null) {
      // Navigate to incident - this would need to be connected to a navigation service
      // For now, we just log it
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    final incidentId = response.payload;
    if (incidentId != null) {
      // Navigate to incident
    }
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
      title: '$category Alert',
      body: '$title - ${distanceKm.toStringAsFixed(1)}km away',
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
  // Handle background messages
  // Note: You cannot access UI from this handler
}
