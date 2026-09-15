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
    // Initialize push notifications without awaiting so we don't block runApp
    // and cause an infinite splash screen if FCM token fetch hangs.
    PushNotificationService().initialize();
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
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _error;
  bool _isSigningIn = false;

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

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Auth Stream Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return const HomeScreen();
        }

        // Auto sign-in anonymously for now, per specs.
        if (FirebaseAuth.instance.currentUser == null && _error == null && !_isSigningIn) {
          _isSigningIn = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (FirebaseAuth.instance.currentUser == null) {
              try {
                await FirebaseAuth.instance.signInAnonymously();
              } catch (e) {
                if (mounted) {
                  setState(() {
                    _error = e.toString();
                    _isSigningIn = false;
                  });
                }
              }
            }
          });
        }

        if (_error != null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Sign-In Failed',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.red),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _error = null;
                        });
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: BoardThemes.brandEmber),
          ),
        );
      },
    );
  }
}
