import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/board_themes.dart';
import '../../core/theme/app_typography.dart';
import '../../models/chess_grade.dart';
import '../../models/user_profile.dart';
import '../dashboard/home_screen.dart';
import '../../state/game_state_notifier.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  ChessGrade _selectedGrade = ChessGrade.intermediate;
  bool _isSaving = false;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController.text = 'Player_${FirebaseAuth.instance.currentUser?.uid.substring(0, 4) ?? '0000'}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _completeSetup() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSaving = true);
    try {
      final firestore = ref.read(firestoreServiceProvider);
      
      final profile = UserProfile(
        uid: uid,
        displayName: _nameController.text.trim(),
        eloRating: _selectedGrade.elo,
        gamesPlayed: 0,
        wins: 0,
        losses: 0,
        draws: 0,
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      );

      await firestore.saveUserProfile(profile);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e'), backgroundColor: BoardThemes.dangerAlert),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BoardThemes.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('INITIAL SETUP', style: AppTypography.titleMedium),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Welcome to Chessical',
                style: TextStyle(
                  color: BoardThemes.pureWhite,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Customize your identity and initial rating.',
                style: TextStyle(color: BoardThemes.mutedSilver, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              Text('DISPLAY NAME', style: AppTypography.labelSmall),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: BoardThemes.pureWhite),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: BoardThemes.surfaceDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: BoardThemes.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: BoardThemes.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: BoardThemes.accentCyan),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              Text('STARTING SKILL LEVEL', style: AppTypography.labelSmall),
              const SizedBox(height: 16),
              
              ...ChessGrade.values.map((grade) {
                final isSelected = grade == _selectedGrade;
                return GestureDetector(
                  onTap: () => setState(() => _selectedGrade = grade),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? grade.color.withAlpha(40) : BoardThemes.surfaceDark,
                      border: Border.all(
                        color: isSelected ? grade.color : BoardThemes.borderSubtle,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: grade.color.withAlpha(50),
                          child: Text(grade.iconSymbol, style: AppTypography.withColor(AppTypography.titleMedium, grade.color)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    grade.title,
                                    style: TextStyle(
                                      color: BoardThemes.pureWhite,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: grade.color.withAlpha(50),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text('${grade.elo} ELO', style: TextStyle(color: grade.color, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(grade.description, style: TextStyle(color: BoardThemes.mutedSilver, fontSize: 12)),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle, color: grade.color),
                      ],
                    ),
                  ),
                );
              }),
              
              const SizedBox(height: 48),
              if (_isSaving)
                const Center(child: CircularProgressIndicator(color: BoardThemes.accentCyan))
              else
                ElevatedButton(
                  onPressed: _completeSetup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BoardThemes.accentCyan,
                    foregroundColor: BoardThemes.pitchBlack,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('COMPLETE SETUP', style: AppTypography.titleMedium.copyWith(color: BoardThemes.pitchBlack)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
