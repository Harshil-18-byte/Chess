import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/chess_constants.dart';
import '../../core/theme/board_themes.dart';
import '../../core/theme/app_typography.dart';
import '../../models/chess_match.dart';
import '../../models/chess_grade.dart';
import '../../models/user_profile.dart';
import '../../state/game_state_notifier.dart';
import 'package:enterprise_chess/views/history/history_screen.dart';
import 'package:enterprise_chess/views/dashboard/match_setup_screen.dart';
import 'package:enterprise_chess/views/settings/settings_screen.dart';
import 'package:enterprise_chess/views/dashboard/profile_screen.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/glass_container.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  UserProfile? _userProfile;
  List<ChessMatch> _pastMatches = [];
  bool _isLoadingProfile = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeAuthAndProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      try {
        var profile = await firestore.getUserProfile(uid).timeout(const Duration(seconds: 5));
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
          // Try to save, but don't block forever if it fails
          try {
            await firestore.saveUserProfile(profile).timeout(const Duration(seconds: 3));
          } catch (_) {}
        }

        final pastMatches = await firestore.getUserMatchHistory(uid).timeout(const Duration(seconds: 5));

        if (mounted) {
          setState(() {
            _userProfile = profile;
            _pastMatches = pastMatches;
            _isLoadingProfile = false;
          });
        }
      } catch (e) {
        // Handle timeout or Firestore exception (e.g. invalid API keys)
        if (mounted) {
          setState(() => _isLoadingProfile = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load profile from database: $e'),
              backgroundColor: BoardThemes.dangerAlert,
            ),
          );
        }
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
          title: Text('Edit Display Name', style: TextStyle(color: BoardThemes.pureWhite)),
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
              child: Text('Cancel'),
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

                if (_userProfile != null) {
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
              child: Text('Save', style: TextStyle(color: BoardThemes.pitchBlack)),
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
            children: [
              Text(
                '♛',
                style: AppTypography.titleLarge,
              ),
              SizedBox(width: 8),
              Text(
                'Select Chess Grade',
                style: TextStyle(
                  color: BoardThemes.pureWhite,
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
                          style: AppTypography.withColor(AppTypography.titleMedium, grade.color),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            grade.title,
                            style: const TextStyle(
                              color: BoardThemes.pureWhite,
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
                          ? Text(
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
              child: Text('Close', style: TextStyle(color: BoardThemes.mutedSilver)),
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
                    Text('♚', style: AppTypography.titleLarge),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Chessical',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: BoardThemes.pureWhite,
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
            child: Text('PROFILE', style: TextStyle(color: BoardThemes.pureWhite, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            child: Text('SETTINGS', style: TextStyle(color: BoardThemes.pureWhite, fontWeight: FontWeight.bold)),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: BoardThemes.accentCyan,
          labelColor: BoardThemes.accentCyan,
          unselectedLabelColor: BoardThemes.mutedSilver,
          tabs: const [
            Tab(text: 'PLAY'),
            Tab(text: 'SOCIAL'),
          ],
        ),
      ),
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
        child: _isLoadingProfile
            ? const LoadingOverlay(message: 'LOADING PROFILE')
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildPlayTab(),
                  _buildSocialTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildPlayTab() {
    return SafeArea(
      child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // Brand Hero Section
                    GlassContainer(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(16),
                      borderRadius: 16,
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
                                child: Center(
                                  child: Text('♚', style: AppTypography.displayMedium),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CHESSICAL',
                                  style: TextStyle(
                                    color: BoardThemes.pureWhite,
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
                      GlassContainer(
                        padding: const EdgeInsets.all(16),
                        borderRadius: 16,
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
                                        style: AppTypography.withColor(AppTypography.titleLarge, currentGrade.color),
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
                                            color: BoardThemes.pureWhite,
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
                                          child: Text(
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
                                                    Text('▼', style: AppTypography.withColor(AppTypography.labelSmall, currentGrade.color)),
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
                    Text('Online Matchmaking', style: BoardThemes.headerMedium),
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
                          foregroundColor: BoardThemes.pitchBlack,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          'Play Online',
                          style: AppTypography.titleMedium,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () => _navigateToMatchSetup('local'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BoardThemes.surfaceCard,
                          foregroundColor: BoardThemes.pureWhite,
                          side: const BorderSide(color: BoardThemes.borderSubtle),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          'Pass & Play (Local)',
                          style: AppTypography.titleMedium,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Section: On-Device Stockfish Engine
                    Text('Play vs Stockfish Engine', style: BoardThemes.headerMedium),
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
                        child: Text(
                          'Play vs Computer',
                          style: AppTypography.titleMedium,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Section: Match History
                    Text('Match History', style: BoardThemes.headerMedium),
                    const SizedBox(height: 12),
                    if (_pastMatches.isEmpty)
                      GlassContainer(
                        padding: const EdgeInsets.all(24),
                        borderRadius: 12,
                        child: Center(
                          child: Text(
                            'No completed matches yet. Start a game above!',
                            style: BoardThemes.bodyRegular,
                          ),
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

                          return GlassContainer(
                            padding: EdgeInsets.zero,
                            margin: EdgeInsets.zero,
                            borderRadius: 10,
                            child: ListTile(
                              leading: Text(
                                match.matchType == 'engine' ? '⚙' : '👤',
                                style: AppTypography.withColor(AppTypography.titleLarge, BoardThemes.mutedSilver),
                              ),
                              title: Text(
                                match.matchType == 'engine'
                                    ? 'vs Stockfish (Level ${match.engineDifficulty ?? 10})'
                                    : 'vs Online Player',
                                style: const TextStyle(
                                  color: BoardThemes.pureWhite,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'Status: ${match.status.name}',
                                style: TextStyle(color: statusColor, fontSize: 12),
                              ),
                              trailing: Text('▶', style: TextStyle(color: BoardThemes.mutedSilver, fontSize: 16)),
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
    );
  }

  Widget _buildSocialTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassContainer(
              padding: const EdgeInsets.all(16),
              borderRadius: 16,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      style: const TextStyle(color: BoardThemes.pureWhite),
                      decoration: InputDecoration(
                        hintText: 'Enter Friend UID',
                        hintStyle: const TextStyle(color: BoardThemes.mutedSilver),
                        filled: true,
                        fillColor: BoardThemes.surfaceDark,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BoardThemes.accentCyan,
                      foregroundColor: BoardThemes.pitchBlack,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    ),
                    child: const Text('ADD'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Pending Invites', style: BoardThemes.headerMedium),
            const SizedBox(height: 12),
            GlassContainer(
              padding: const EdgeInsets.all(24),
              borderRadius: 12,
              child: Center(
                child: Text(
                  'No pending invites.',
                  style: BoardThemes.bodyRegular,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Friends List', style: BoardThemes.headerMedium),
            const SizedBox(height: 12),
            GlassContainer(
              padding: const EdgeInsets.all(24),
              borderRadius: 12,
              child: Center(
                child: Text(
                  'You haven\'t added any friends yet.',
                  style: BoardThemes.bodyRegular,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

