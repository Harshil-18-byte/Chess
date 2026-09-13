import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/theme/board_themes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'views/home_screen.dart';
import 'services/push_notification_service.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Initialize push notifications after Firebase is ready
    await PushNotificationService().initialize();
  } catch (_) {
    // If running in offline test or mock harness
  }

  runApp(
    ProviderScope(
      overrides: [
        if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const EnterpriseChessApp(),
    ),
  );
}

/// Root Application Widget for Chessical.
class EnterpriseChessApp extends StatelessWidget {
  const EnterpriseChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: PushNotificationService.navigatorKey,
      title: 'Chessical',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: BoardThemes.scaffoldBackground,
        primaryColor: BoardThemes.brandEmber,
        textTheme: GoogleFonts.interTextTheme(
          ThemeData(brightness: Brightness.dark).textTheme,
        ),
        colorScheme: const ColorScheme.dark(
          primary: BoardThemes.brandEmber,
          secondary: BoardThemes.brandGlow,
          surface: BoardThemes.surfaceDark,
          error: BoardThemes.dangerAlert,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: BoardThemes.surfaceDark,
          elevation: 0,
          centerTitle: false,
        ),
      ),
      builder: (context, child) {
        return Consumer(
          builder: (context, ref, _) {
            final reduceMotion = ref.watch(reduceMotionProvider);
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: reduceMotion,
              ),
              child: child!,
            );
          },
        );
      },
      home: const AuthGate(),
    );
  }
}

/// Gatekeeper that ensures the user is authenticated before showing the app.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: BoardThemes.brandEmber),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return const HomeScreen();
        }

        // Auto sign-in anonymously for now, per specs.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          FirebaseAuth.instance.signInAnonymously();
        });

        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: BoardThemes.brandEmber),
          ),
        );
      },
    );
  }
}
