import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'data/services/push_notification_service.dart';
import 'presentation/providers/incident_provider.dart';
import 'presentation/providers/user_provider.dart';
import 'presentation/providers/alert_settings_provider.dart';
import 'presentation/providers/vote_provider.dart';
import 'presentation/providers/community_provider.dart';
import 'presentation/providers/category_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/comment_provider.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/auth_screen.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => IncidentProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => AlertSettingsProvider()),
        ChangeNotifierProvider(create: (_) => VoteProvider()),
        ChangeNotifierProvider(create: (_) => CommunityProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => CommentProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'SafeTrace',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const AuthGate(),
          );
        },
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
  @override
  void initState() {
    super.initState();
    _loadUser();
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
        await PushNotificationService().initialize(widget.firebaseUser.uid);
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

    return const HomeScreen();
  }
}
