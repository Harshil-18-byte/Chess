import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/board_themes.dart';
import '../../core/theme/app_typography.dart';
import '../../services/firestore_service.dart';
import '../../state/game_state_notifier.dart';
import '../../models/user_profile.dart';
import 'package:enterprise_chess/views/history/match_history_list_screen.dart';
import 'widgets/performance_graph.dart';


class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  UserProfile? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    final service = FirestoreService();
    final profile = await service.getUserProfile(uid);
    if (mounted) {
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    }
  }

  void _showEditDisplayNameDialog() {
    final controller = TextEditingController(text: _profile?.displayName ?? '');
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: BoardThemes.surfaceCard,
          title: const Text('Edit Display Name', style: TextStyle(color: BoardThemes.pureWhite)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: BoardThemes.pureWhite),
            decoration: const InputDecoration(
              labelText: 'Name',
              labelStyle: TextStyle(color: BoardThemes.accentCyan),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = controller.text.trim();
                final validNameRegex = RegExp(r'^[a-zA-Z0-9_]{3,20}$');
                
                if (!validNameRegex.hasMatch(newName)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Name must be 3-20 characters (letters, numbers, underscores only).'),
                      backgroundColor: BoardThemes.dangerAlert,
                    ),
                  );
                  return;
                }

                if (_profile != null) {
                  final updated = _profile!.copyWith(displayName: newName);
                  await ref.read(firestoreServiceProvider).saveUserProfile(updated);
                  if (mounted) {
                    setState(() => _profile = updated);
                  }
                }
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: BoardThemes.accentCyan),
              child: const Text('Save', style: TextStyle(color: BoardThemes.pitchBlack)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BoardThemes.scaffoldBackground,
      appBar: AppBar(
        title: Text('PROFILE', style: AppTypography.titleMedium),
        backgroundColor: BoardThemes.surfaceDark,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Center(
            child: Text(
              'BACK',
              style: TextStyle(
                color: BoardThemes.pureWhite,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: BoardThemes.pureWhite))
          : _profile == null
              ? const Center(
                  child: Text('Profile not found', style: TextStyle(color: BoardThemes.mutedSilver)),
                )
              : _buildProfileContent(),
    );
  }

  Widget _buildProfileContent() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: BoardThemes.surfaceCard,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                'U', // No icons allowed
                style: TextStyle(
                  color: BoardThemes.pureWhite,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _profile!.displayName,
                style: const TextStyle(
                  color: BoardThemes.pureWhite,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: _showEditDisplayNameDialog,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '[EDIT]',
                  style: TextStyle(
                    color: BoardThemes.mutedSilver,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'ELO: ${_profile!.eloRating}',
            style: const TextStyle(
              color: BoardThemes.mutedSilver,
              fontSize: 18,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem('WINS', _profile!.wins.toString()),
            _buildStatItem('DRAWS', _profile!.draws.toString()),
            _buildStatItem('LOSSES', _profile!.losses.toString()),
          ],
        ),
        const SizedBox(height: 32),
        Center(
          child: Column(
            children: [
              Text(
                'Games Played: ${_profile!.gamesPlayed}',
                style: const TextStyle(
                  color: BoardThemes.mutedSilver,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Last Active: ${_profile!.lastActiveAt.toLocal().toString().split('.')[0]}',
                style: const TextStyle(
                  color: BoardThemes.mutedSilver,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        // Add PerformanceGraph
        PerformanceGraph(
          ratings: [1200, 1225, 1210, 1250, 1240, 1280, _profile!.eloRating.toDouble()],
          labels: const ['Game 1', 'Game 2', 'Game 3', 'Game 4', 'Game 5', 'Game 6', 'Latest'],
        ),
        const SizedBox(height: 32),
        GestureDetector(
          onTap: () {
            if (_profile != null) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => MatchHistoryListScreen(uid: _profile!.uid),
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            decoration: BoxDecoration(
              color: BoardThemes.surfaceCard,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: BoardThemes.borderSubtle),
            ),
            child: const Center(
              child: Text(
                'VIEW MATCH HISTORY',
                style: TextStyle(
                  color: BoardThemes.pureWhite,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: BoardThemes.pureWhite,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: BoardThemes.mutedSilver,
            fontSize: 12,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}
