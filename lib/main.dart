import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'data/services/push_notification_service.dart';
import 'presentation/providers/incident_provider.dart';
import 'presentation/providers/user_provider.dart';
import 'presentation/providers/alert_settings_provider.dart';
import 'presentation/providers/vote_provider.dart';
import 'presentation/providers/community_provider.dart';
import 'presentation/providers/category_provider.dart';
import 'presentation/providers/comment_provider.dart';
import 'presentation/providers/flag_provider.dart';
import 'presentation/providers/post_provider.dart';
import 'presentation/providers/system_config_provider.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/auth_screen.dart';
import 'presentation/screens/community_detail_screen.dart';
import 'presentation/widgets/incident_bottom_sheet.dart';
import 'presentation/screens/admin_web/admin_web_shell.dart';
import 'presentation/screens/admin_web/admin_auth_screen.dart';
import 'presentation/screens/admin_web/access_denied_screen.dart';
import 'utils/app_theme.dart';

/// Global navigator key for navigation from services (e.g., notification taps)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Disable Firestore IndexedDB persistence on web to prevent
  // "INTERNAL ASSERTION FAILED: Unexpected state" race condition
  // that occurs when multiple listeners start simultaneously.
  if (kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
  }

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const SafeTraceApp());
}

class SafeTraceApp extends StatelessWidget {
  const SafeTraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => IncidentProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => AlertSettingsProvider()),
        ChangeNotifierProvider(create: (_) => VoteProvider()),
        ChangeNotifierProvider(create: (_) => CommunityProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => CommentProvider()),
        ChangeNotifierProvider(create: (_) => FlagProvider()),
        ChangeNotifierProvider(create: (_) => PostProvider()),
        ChangeNotifierProvider(create: (_) => SystemConfigProvider()),
      ],
      child: MaterialApp(
        title: 'SafeTrace',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          final firebaseUser = snapshot.data!;
          return _UserLoader(firebaseUser: firebaseUser);
        }

        // Use web-specific auth screen for admin dashboard
        if (kIsWeb) {
          return const AdminAuthScreen();
        }
        return const AuthScreen();
      },
    );
  }
}

class _UserLoader extends StatefulWidget {
  final User firebaseUser;

  const _UserLoader({required this.firebaseUser});

  @override
  State<_UserLoader> createState() => _UserLoaderState();
}

class _UserLoaderState extends State<_UserLoader> {
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _loadUser();
    _initDeepLinks();
  }

  void _initDeepLinks() {
    // Handle deep links while app is running
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
    // Handle deep link that launched the app
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme == 'safetrace' && uri.host == 'incident') {
      final incidentId = uri.queryParameters['id'];
      if (incidentId != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => IncidentBottomSheet(incidentId: incidentId),
            );
          }
        });
      }
    }
  }

  void _loadUser() async {
    final userProvider = context.read<UserProvider>();
    if (userProvider.currentUser == null && !userProvider.isLoading) {
      await userProvider.loadOrCreateUser(
        widget.firebaseUser.uid,
        widget.firebaseUser.email ?? '',
      );

      // Initialize push notifications after user is loaded
      if (mounted) {
        final pushService = PushNotificationService();
        pushService.setNavigatorKey(navigatorKey);
        pushService.setOnIncidentTap((context, incidentId) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => IncidentBottomSheet(incidentId: incidentId),
          );
        });
        pushService.setOnCommunityTap((context, communityId) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CommunityDetailScreen(communityId: communityId),
            ),
          );
        });
        await pushService.initialize(widget.firebaseUser.uid);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();

    if (userProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (userProvider.currentUser == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load user: ${userProvider.error ?? "Unknown error"}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadUser,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Web platform routing - show admin panel for admins, access denied for others
    if (kIsWeb) {
      if (userProvider.currentUser!.isAdmin) {
        return const AdminWebShell();
      } else {
        return const AccessDeniedScreen();
      }
    }

    // Mobile platform - show normal home screen
    return const HomeScreen();
  }
}
