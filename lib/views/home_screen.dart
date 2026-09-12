import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/chess_constants.dart';
import '../core/theme/board_themes.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/liquid_glass.dart';
import '../models/chess_match.dart';
import '../models/chess_grade.dart';
import '../models/user_profile.dart';
import '../state/game_state_notifier.dart';
import 'game_board/game_board_view.dart';
import 'history_screen.dart';

/// Main Lobby and Matchmaking entry point.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isQueueing = false;
  String? _queuedTimeControl;
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

  Future<void> _startOnlineMatchmaking(int timeControlMillis, String label) async {
    final auth = ref.read(authServiceProvider);
    final firestore = ref.read(firestoreServiceProvider);
    final uid = auth.currentUid;
    if (uid.isEmpty) return;

    setState(() {
      _isQueueing = true;
      _queuedTimeControl = label;
    });

    try {
      final matchId = await firestore.findOrCreateMatchmakingMatch(
        uid: uid,
        timeControlMillis: timeControlMillis,
      );

      if (!mounted) return;

      if (matchId != null) {
        setState(() => _isQueueing = false);
        _navigateToMatch(matchId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Joined $label queue. Searching for opponent...'),
            backgroundColor: BoardThemes.accentCyan,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isQueueing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Matchmaking error: $e'), backgroundColor: BoardThemes.dangerAlert),
        );
      }
    }
  }

  Future<void> _cancelMatchmaking() async {
    final auth = ref.read(authServiceProvider);
    final firestore = ref.read(firestoreServiceProvider);
    final uid = auth.currentUid;
    if (uid.isNotEmpty) {
      await firestore.leaveMatchmakingQueue(uid);
    }
    if (mounted) {
      setState(() {
        _isQueueing = false;
        _queuedTimeControl = null;
      });
    }
  }

  Future<void> _startEngineMatch(int difficulty, String label) async {
    final auth = ref.read(authServiceProvider);
    final firestore = ref.read(firestoreServiceProvider);
    final uid = auth.currentUid.isNotEmpty ? auth.currentUid : 'player_local';

    final match = await firestore.createMatch(
      whiteUid: uid,
      blackUid: 'engine_stockfish',
      matchType: 'engine',
      timeControlMillis: ChessConstants.rapidMillis,
      engineDifficulty: difficulty,
    );

    if (mounted) {
      _navigateToMatch(match.matchId);
    }
  }

  void _navigateToMatch(String matchId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GameBoardView(matchId: matchId),
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

  Widget _buildGradeEngineCard(ChessGrade grade) {
    return GestureDetector(
      onTap: () => _startEngineMatch(grade.stockfishSkill, grade.title),
      child: LiquidGlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  grade.iconSymbol,
                  style: AppTypography.titleLarge.copyWith(fontSize: 22),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: BoardThemes.borderHairline,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: BoardThemes.mutedSilver.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Lvl ${grade.stockfishSkill}',
                    style: AppTypography.labelSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              grade.title,
              style: AppTypography.labelLarge.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              '${grade.elo} Elo',
              style: AppTypography.bodySmall,
            ),
          ],
        ),
      ),
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
      ),
      body: _isLoadingProfile
          ? const Center(
              child: CircularProgressIndicator(color: BoardThemes.brandEmber),
            )
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
                                child: const Icon(Icons.shield, color: BoardThemes.brandEmber),
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
                    // Queueing status banner
                    if (_isQueueing)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: BoardThemes.accentCyan.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: BoardThemes.accentCyan),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: BoardThemes.accentCyan,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Searching opponent in $_queuedTimeControl...',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _cancelMatchmaking,
                              child: const Text('Cancel', style: TextStyle(color: BoardThemes.dangerAlert)),
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
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 14, color: Colors.white70),
                                          onPressed: _showEditDisplayNameDialog,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
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
                                                    Icon(Icons.expand_more, size: 12, color: currentGrade.color),
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
                    Row(
                      children: [
                        Expanded(
                          child: _buildModeCard(
                            title: 'Bullet',
                            time: '1 min',
                            icon: Icons.bolt,
                            accent: BoardThemes.accentRose,
                            onTap: () =>
                                _startOnlineMatchmaking(ChessConstants.bulletMillis, 'Bullet (1m)'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildModeCard(
                            title: 'Blitz',
                            time: '3 min',
                            icon: Icons.timer,
                            accent: BoardThemes.accentGold,
                            onTap: () =>
                                _startOnlineMatchmaking(ChessConstants.blitzMillis, 'Blitz (3m)'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildModeCard(
                            title: 'Rapid',
                            time: '10 min',
                            icon: Icons.hourglass_bottom,
                            accent: BoardThemes.accentCyan,
                            onTap: () =>
                                _startOnlineMatchmaking(ChessConstants.rapidMillis, 'Rapid (10m)'),
                          ),
                        ),
                      ],
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
                    Row(
                      children: [
                        Expanded(child: _buildGradeEngineCard(ChessGrade.beginner)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildGradeEngineCard(ChessGrade.novice)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildGradeEngineCard(ChessGrade.intermediate)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildGradeEngineCard(ChessGrade.advanced)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildGradeEngineCard(ChessGrade.master)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildGradeEngineCard(ChessGrade.grandmaster)),
                      ],
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
                              leading: Icon(
                                match.matchType == 'engine'
                                    ? Icons.smart_toy_outlined
                                    : Icons.people_outline,
                                color: BoardThemes.accentCyan,
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
                              trailing: const Icon(Icons.chevron_right, color: Colors.white54),
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

  Widget _buildModeCard({
    required String title,
    required String time,
    required IconData icon,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          color: BoardThemes.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BoardThemes.borderSubtle),
        ),
        child: Column(
          children: [
            Icon(icon, color: accent, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              time,
              style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
