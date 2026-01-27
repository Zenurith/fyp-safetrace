import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'presentation/providers/incident_provider.dart';
import 'presentation/providers/user_provider.dart';
import 'presentation/providers/alert_settings_provider.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/auth_screen.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
      ],
      child: MaterialApp(
        title: 'SafeTrace',
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
          final userProvider = context.read<UserProvider>();
          if (userProvider.currentUser == null && !userProvider.isLoading) {
            userProvider.loadOrCreateUser(
              firebaseUser.uid,
              firebaseUser.email ?? '',
            );
          }
          return const HomeScreen();
        }

        return const AuthScreen();
      },
    );
  }
}
