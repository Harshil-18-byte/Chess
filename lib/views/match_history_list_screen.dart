import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/board_themes.dart';
import '../core/theme/app_typography.dart';
import '../models/chess_match.dart';
import '../state/game_state_notifier.dart';
import 'history_screen.dart';

class MatchHistoryListScreen extends ConsumerStatefulWidget {
  final String uid;

  const MatchHistoryListScreen({super.key, required this.uid});

  @override
  ConsumerState<MatchHistoryListScreen> createState() => _MatchHistoryListScreenState();
}

class _MatchHistoryListScreenState extends ConsumerState<MatchHistoryListScreen> {
  List<ChessMatch> _pastMatches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final firestore = ref.read(firestoreServiceProvider);
    final pastMatches = await firestore.getUserMatchHistory(widget.uid);
    if (mounted) {
      setState(() {
        _pastMatches = pastMatches;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BoardThemes.scaffoldBackground,
      appBar: AppBar(
        title: Text('MATCH HISTORY', style: AppTypography.titleMedium),
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
          : _pastMatches.isEmpty
              ? const Center(
                  child: Text('No completed matches yet.', style: TextStyle(color: BoardThemes.mutedSilver)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _pastMatches.length,
                  separatorBuilder: (context, i) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final match = _pastMatches[index];
                    final isWinner = match.winnerUid == widget.uid;
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
    );
  }
}
