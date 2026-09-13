import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/chess_constants.dart';
import '../core/theme/board_themes.dart';
import '../models/chess_match.dart';
import '../models/chess_grade.dart';
import '../models/user_profile.dart';
import '../state/game_state_notifier.dart';
import 'history_screen.dart';
import 'match_setup_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import 'widgets/loading_overlay.dart';

/// Main Lobby and Matchmaking entry point.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  UserProfile? _userProfile;
  List<ChessMatch> _pastMatches = [];
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _initializeAuthAndProfile();
  }

  Future<void> _initializeAuthAndProfile() async {
    final auth = ref.read(authServiceProvider);
    final firestore = ref.read(firestoreServiceProvider);

    if (auth.currentUser == null) {
      try {
        await auth.signInAnonymously();
      } catch (_) {}
    }

    final uid = auth.currentUid;
    if (uid.isNotEmpty) {
      var profile = await firestore.getUserProfile(uid);
      if (profile == null) {
        profile = UserProfile(
          uid: uid,
          displayName: 'Grandmaster_${uid.length >= 4 ? uid.substring(0, 4) : uid}',
          eloRating: ChessConstants.defaultElo,
          gamesPlayed: 0,
          wins: 0,
          losses: 0,
          draws: 0,
          createdAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        );
        await firestore.saveUserProfile(profile);
      }

      final pastMatches = await firestore.getUserMatchHistory(uid);

      if (mounted) {
        setState(() {
          _userProfile = profile;
          _pastMatches = pastMatches;
          _isLoadingProfile = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  void _navigateToMatchSetup(String matchType) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MatchSetupScreen(matchType: matchType),
      ),
    ).then((_) {
      if (mounted) {
        _initializeAuthAndProfile();
      }
    });
  }

  void _showEditDisplayNameDialog() {
    final controller = TextEditingController(text: _userProfile?.displayName ?? '');
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: BoardThemes.surfaceCard,
          title: const Text('Edit Display Name', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
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
                if (newName.isNotEmpty && _userProfile != null) {
                  final updated = _userProfile!.copyWith(displayName: newName);
                  await ref.read(firestoreServiceProvider).saveUserProfile(updated);
                  if (mounted) {
                    setState(() => _userProfile = updated);
                  }
                }
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: BoardThemes.accentCyan),
              child: const Text('Save', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  void _showGradeSelectionDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final currentGrade = _userProfile != null
            ? ChessGrade.fromElo(_userProfile!.eloRating)
            : ChessGrade.intermediate;

        return AlertDialog(
          backgroundColor: BoardThemes.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Text(
                '♛',
                style: TextStyle(fontSize: 22, color: BoardThemes.pureWhite),
              ),
              SizedBox(width: 8),
              Text(
                'Select Chess Grade',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: ChessGrade.values.map((grade) {
                  final isSelected = grade == currentGrade;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? grade.color.withAlpha(35) : BoardThemes.surfaceDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? grade.color : BoardThemes.borderSubtle,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: grade.color.withAlpha(30),
                        child: Text(
                          grade.iconSymbol,
                          style: TextStyle(fontSize: 20, color: grade.color),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            grade.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: grade.color.withAlpha(30),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '~${grade.elo} Elo',
                              style: TextStyle(
                                color: grade.color,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        grade.description,
                        style: BoardThemes.bodyRegular.copyWith(fontSize: 11),
                      ),
                      trailing: isSelected
                          ? const Text(
                              '●',
                              style: TextStyle(
                                color: BoardThemes.pureWhite,
                                fontSize: 18,
                              ),
                            )
                          : null,
                      onTap: () async {
                        if (_userProfile != null) {
                          final updated = _userProfile!.copyWith(eloRating: grade.elo);
                          await ref.read(firestoreServiceProvider).saveUserProfile(updated);
                          if (mounted) {
                            setState(() => _userProfile = updated);
                          }
                        }
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close', style: TextStyle(color: Colors.white70)),
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
        backgroundColor: BoardThemes.surfaceDark,
        elevation: 0,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/images/logo.png',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Text('♚', style: TextStyle(fontSize: 24, color: BoardThemes.pureWhite)),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Chessical',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
            child: const Text('PROFILE', style: TextStyle(color: BoardThemes.pureWhite, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            child: const Text('SETTINGS', style: TextStyle(color: BoardThemes.pureWhite, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _isLoadingProfile
          ? const LoadingOverlay(message: 'LOADING PROFILE')
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand Hero Section
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            BoardThemes.surfaceDark,
                            BoardThemes.brandEmber.withAlpha(40),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: BoardThemes.brandEmber.withAlpha(80)),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 64,
                                height: 64,
                                color: BoardThemes.brandEmber.withAlpha(50),
                                child: const Center(
                                  child: Text('♚', style: TextStyle(fontSize: 32, color: BoardThemes.pureWhite)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'CHESSICAL',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Obsidian Engine & Real-Time 3D Grandmaster Arena',
                                  style: TextStyle(
                                    color: BoardThemes.brandGlow,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Profile Card
                    if (_userProfile != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: BoardThemes.surfaceDark,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: BoardThemes.borderSubtle),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black38,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Builder(
                                  builder: (context) {
                                    final currentGrade = ChessGrade.fromElo(_userProfile!.eloRating);
                                    return CircleAvatar(
                                      radius: 26,
                                      backgroundColor: currentGrade.color.withAlpha(30),
                                      child: Text(
                                        currentGrade.iconSymbol,
                                        style: TextStyle(fontSize: 26, color: currentGrade.color),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          _userProfile!.displayName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
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
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Builder(
                                      builder: (context) {
                                        final currentGrade = ChessGrade.fromElo(_userProfile!.eloRating);
                                        return Row(
                                          children: [
                                            Text(
                                              '${_userProfile!.eloRating} Elo',
                                              style: const TextStyle(
                                                color: BoardThemes.accentGold,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            InkWell(
                                              onTap: _showGradeSelectionDialog,
                                              borderRadius: BorderRadius.circular(10),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: currentGrade.color.withAlpha(30),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(color: currentGrade.color.withAlpha(120)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      currentGrade.title,
                                                      style: TextStyle(
                                                        color: currentGrade.color,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 3),
                                                    Text('▼', style: TextStyle(fontSize: 10, color: currentGrade.color)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            // Stats Summary
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${_userProfile!.wins}W - ${_userProfile!.losses}L - ${_userProfile!.draws}D',
                                  style: const TextStyle(
                                    color: BoardThemes.accentEmerald,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '${_userProfile!.gamesPlayed} Played',
                                  style: BoardThemes.bodyRegular.copyWith(fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Section: Online Multiplayer
                    const Text('Online Matchmaking', style: BoardThemes.headerMedium),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_userProfile?.isBanned == true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Your account has been banned from online play.'),
                                backgroundColor: BoardThemes.dangerAlert,
                              ),
                            );
                            return;
                          }
                          _navigateToMatchSetup('human');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BoardThemes.accentCyan,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text(
                          'Play Online',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Section: On-Device Stockfish Engine
                    const Text('Play vs Stockfish Engine', style: BoardThemes.headerMedium),
                    const SizedBox(height: 6),
                    Text(
                      'Zero-latency local evaluation via background isolate FFI',
                      style: BoardThemes.bodyRegular.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () => _navigateToMatchSetup('engine'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BoardThemes.surfaceCard,
                          foregroundColor: BoardThemes.pureWhite,
                          side: const BorderSide(color: BoardThemes.borderSubtle),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text(
                          'Play vs Computer',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Section: Match History
                    const Text('Match History', style: BoardThemes.headerMedium),
                    const SizedBox(height: 12),
                    if (_pastMatches.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: BoardThemes.surfaceDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: BoardThemes.borderSubtle),
                        ),
                        child: Text(
                          'No completed matches yet. Start a game above!',
                          style: BoardThemes.bodyRegular,
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _pastMatches.length,
                        separatorBuilder: (context, i) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final match = _pastMatches[index];
                          final isWinner = match.winnerUid == _userProfile?.uid;
                          final isDraw = match.status.name.startsWith('draw');

                          Color statusColor;
                          if (isDraw) {
                            statusColor = BoardThemes.accentGold;
                          } else if (isWinner) {
                            statusColor = BoardThemes.accentEmerald;
                          } else {
                            statusColor = BoardThemes.dangerAlert;
                          }

                          return Container(
                            decoration: BoxDecoration(
                              color: BoardThemes.surfaceDark,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: BoardThemes.borderSubtle),
                            ),
                            child: ListTile(
                              leading: Text(
                                match.matchType == 'engine' ? '⚙' : '👤',
                                style: const TextStyle(fontSize: 24, color: BoardThemes.mutedSilver),
                              ),
                              title: Text(
                                match.matchType == 'engine'
                                    ? 'vs Stockfish (Level ${match.engineDifficulty ?? 10})'
                                    : 'vs Online Player',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'Status: ${match.status.name}',
                                style: TextStyle(color: statusColor, fontSize: 12),
                              ),
                              trailing: const Text('▶', style: TextStyle(color: BoardThemes.mutedSilver, fontSize: 16)),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => HistoryScreen(match: match),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
