import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme/board_themes.dart';
import 'views/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Note: Firebase.initializeApp() is called if Firebase credentials exist in environment
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
