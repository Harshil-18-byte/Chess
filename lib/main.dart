import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/board_themes.dart';
import 'firebase_options.dart';
import 'views/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // If running in offline test or mock harness
  }

  runApp(
    const ProviderScope(
      child: EnterpriseChessApp(),
    ),
  );
}

/// Root Application Widget for Chessical.
class EnterpriseChessApp extends StatelessWidget {
  const EnterpriseChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      home: const HomeScreen(),
    );
  }
}
