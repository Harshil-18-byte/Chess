import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/board_themes.dart';
import '../../core/theme/app_typography.dart';
import '../widgets/glass_container.dart';
import 'profile_setup_screen.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _isLoading = false;

  Future<void> _signInAsGuest() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInAnonymously();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ProfileSetupScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: BoardThemes.dangerAlert),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BoardThemes.scaffoldBackground,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.5, -0.8),
            radius: 1.2,
            colors: [
              Color(0xFF1E293B),
              BoardThemes.surfaceDark,
              Color(0xFF000000),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                // Branding
                Center(
                  child: GlassContainer(
                    padding: const EdgeInsets.all(24),
                    borderRadius: 24,
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                            errorBuilder: (context, _, _) => Container(
                              width: 96,
                              height: 96,
                              color: BoardThemes.brandEmber.withAlpha(50),
                              child: Center(child: Text('♚', style: AppTypography.displayMedium)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'CHESSICAL',
                          style: TextStyle(
                            color: BoardThemes.pureWhite,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Obsidian Engine & Real-Time Arena',
                          style: TextStyle(
                            color: BoardThemes.brandGlow,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                // Auth Buttons
                if (_isLoading)
                  const Center(child: CircularProgressIndicator(color: BoardThemes.accentCyan))
                else ...[
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Google Sign-In requires Client IDs to be configured. Use Guest.'))
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BoardThemes.surfaceCard,
                      foregroundColor: BoardThemes.pureWhite,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: BoardThemes.borderSubtle),
                    ),
                    child: Text('CONTINUE WITH GOOGLE', style: AppTypography.titleMedium),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Apple Sign-In requires Developer Account config. Use Guest.'))
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BoardThemes.surfaceCard,
                      foregroundColor: BoardThemes.pureWhite,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: BoardThemes.borderSubtle),
                    ),
                    child: Text('CONTINUE WITH APPLE', style: AppTypography.titleMedium),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Expanded(child: Divider(color: BoardThemes.borderSubtle)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('OR', style: TextStyle(color: BoardThemes.mutedSilver, fontWeight: FontWeight.bold)),
                      ),
                      const Expanded(child: Divider(color: BoardThemes.borderSubtle)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _signInAsGuest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BoardThemes.accentCyan,
                      foregroundColor: BoardThemes.pitchBlack,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('PLAY AS GUEST', style: AppTypography.titleMedium.copyWith(color: BoardThemes.pitchBlack)),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
