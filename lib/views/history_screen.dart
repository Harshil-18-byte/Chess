import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/board_themes.dart';
import '../models/chess_match.dart';
import '../models/chess_move.dart';
import '../state/game_state_notifier.dart';
import 'game_board/widgets/board_square.dart';

/// Read-only historical match viewer allowing step-by-step navigation through move history.
class HistoryScreen extends ConsumerStatefulWidget {
  final ChessMatch match;

  const HistoryScreen({super.key, required this.match});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  int _currentMoveIndex = 0; // 0 = initial position, 1..N = moves
  List<ChessMove> _moves = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMoves();
  }

  Future<void> _loadMoves() async {
    final firestore = ref.read(firestoreServiceProvider);
    final movesStream = firestore.getMovesStream(widget.match.matchId);
    final moves = await movesStream.first;

    if (mounted) {
      setState(() {
        _moves = moves;
        _currentMoveIndex = moves.length; // Default to end of match
        _isLoading = false;
      });
    }
  }

  Map<int, String> _parseFenToBoardMap(String fen) {
    final boardMap = <int, String>{};
    final fenParts = fen.split(' ');
    final positionPart = fenParts.isNotEmpty ? fenParts[0] : '';
    final ranks = positionPart.split('/');

    for (int rankIndex = 0; rankIndex < 8 && rankIndex < ranks.length; rankIndex++) {
      final rankStr = ranks[rankIndex];
      int fileIndex = 0;
      for (int i = 0; i < rankStr.length; i++) {
        final char = rankStr[i];
        final digit = int.tryParse(char);
        if (digit != null) {
          fileIndex += digit;
        } else {
          final linearIndex = rankIndex * 8 + fileIndex;
          boardMap[linearIndex] = char;
          fileIndex++;
        }
      }
    }
    return boardMap;
  }

  String get _activeFen {
    if (_moves.isEmpty || _currentMoveIndex == 0) {
      return 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
    }
    final index = (_currentMoveIndex - 1).clamp(0, _moves.length - 1);
    return _moves[index].fenAfterMove;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: BoardThemes.scaffoldBackground,
        body: Center(
          child: CircularProgressIndicator(color: BoardThemes.accentCyan),
        ),
      );
    }

    final boardMap = _parseFenToBoardMap(_activeFen);
    final activeMove =
        _currentMoveIndex > 0 && _currentMoveIndex <= _moves.length
            ? _moves[_currentMoveIndex - 1]
            : null;

    return Scaffold(
      backgroundColor: BoardThemes.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: BoardThemes.surfaceDark,
        elevation: 0,
        title: Text(
          'Review: ${widget.match.matchId.substring(0, 8)}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Match outcome banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: BoardThemes.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: BoardThemes.borderSubtle),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Result: ${widget.match.status.name}',
                            style: const TextStyle(
                              color: BoardThemes.accentGold,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'Type: ${widget.match.matchType} | Total Moves: ${_moves.length}',
                            style: BoardThemes.bodyRegular.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                      Chip(
                        backgroundColor: BoardThemes.surfaceCard,
                        label: Text(
                          activeMove != null
                              ? 'Move $_currentMoveIndex/${_moves.length}: ${activeMove.san}'
                              : 'Start Position',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Read-only Board Canvas
                LayoutBuilder(
                  builder: (context, constraints) {
                    final boardSize = constraints.maxWidth.clamp(280.0, 520.0);
                    return Container(
                      width: boardSize,
                      height: boardSize,
                      decoration: BoxDecoration(
                        border: Border.all(color: BoardThemes.borderSubtle, width: 3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 8,
                        ),
                        itemCount: 64,
                        itemBuilder: (context, index) {
                          final pieceChar = boardMap[index];
                          return BoardSquareWidget(
                            linearIndex: index,
                            isFlipped: false,
                            pieceChar: pieceChar,
                            canDragPiece: false,
                            onTap: () {},
                            onPieceDropped: (_) {},
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Step Forward / Backward Navigation Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _NavButton(
                      label: '|\u25c2',
                      enabled: _currentMoveIndex > 0,
                      onTap: () => setState(() => _currentMoveIndex = 0),
                    ),
                    _NavButton(
                      label: '\u25c2',
                      enabled: _currentMoveIndex > 0,
                      onTap: () => setState(() => _currentMoveIndex--),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '$_currentMoveIndex / ${_moves.length}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    _NavButton(
                      label: '\u25b8',
                      enabled: _currentMoveIndex < _moves.length,
                      onTap: () => setState(() => _currentMoveIndex++),
                    ),
                    _NavButton(
                      label: '\u25b8|',
                      enabled: _currentMoveIndex < _moves.length,
                      onTap: () => setState(() => _currentMoveIndex = _moves.length),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Moves SAN List Grid
                Container(
                  height: 140,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: BoardThemes.surfaceDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: BoardThemes.borderSubtle),
                  ),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 2.4,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                    ),
                    itemCount: _moves.length,
                    itemBuilder: (context, index) {
                      final move = _moves[index];
                      final isSelected = _currentMoveIndex == index + 1;
                      return InkWell(
                        onTap: () => setState(() => _currentMoveIndex = index + 1),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? BoardThemes.accentCyan
                                : BoardThemes.surfaceCard,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${move.moveNumber}. ${move.san}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NavButton — text-based navigation control (zero-icon policy).
// ─────────────────────────────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? Colors.white.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: enabled ? Colors.white : Colors.white24,
          ),
        ),
      ),
    );
  }
}
