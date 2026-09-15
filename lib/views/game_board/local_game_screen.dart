import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess/chess.dart' as chess_lib;
import 'dart:math' as math;
import '../../../core/theme/board_themes.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/liquid_glass.dart';
import '../../../models/chess_match.dart';
import '../../../services/audio_service.dart';
import '../../../services/pgn_service.dart';
import '../../../state/game_state_notifier.dart';
import 'widgets/board_square.dart';
import 'widgets/game_clock.dart';
import 'widgets/captured_pieces_tray.dart';
import 'widgets/piece_promotion_sheet.dart';
import 'widgets/move_history_pane.dart';

class LocalGameScreen extends ConsumerStatefulWidget {
  final String matchId;

  const LocalGameScreen({
    super.key,
    required this.matchId,
  });

  @override
  ConsumerState<LocalGameScreen> createState() => _LocalGameScreenState();
}

class _LocalGameScreenState extends ConsumerState<LocalGameScreen> {
  String? _selectedSquare;
  List<String> _legalDestinations = [];
  String? _lastMoveFrom;
  String? _lastMoveTo;

  bool _autoRotate = true; // Auto-rotate is the default setting per user request

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(gameStateNotifierProvider.notifier).setActiveMatch(widget.matchId);
    });
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

  void _onSquareTapped(String square, String? pieceOnSquare, ChessMatch match) {
    if (!match.isActive) return;

    final isWhiteTurn = match.activeTurn == 'w';

    if (_selectedSquare != null) {
      if (_legalDestinations.contains(square)) {
        _processMoveAttempt(_selectedSquare!, square, match);
        setState(() {
          _selectedSquare = null;
          _legalDestinations = [];
        });
        return;
      }
    }

    if (pieceOnSquare != null) {
      final isPieceWhite = pieceOnSquare == pieceOnSquare.toUpperCase();
      if ((isWhiteTurn && isPieceWhite) || (!isWhiteTurn && !isPieceWhite)) {
        final destinations =
            ref.read(gameStateNotifierProvider.notifier).getLegalDestinations(square);
        setState(() {
          _selectedSquare = square;
          _legalDestinations = destinations;
        });
        return;
      }
    }

    setState(() {
      _selectedSquare = null;
      _legalDestinations = [];
    });
  }

  Future<void> _processMoveAttempt(
    String from,
    String to,
    ChessMatch match,
  ) async {
    final chess = chess_lib.Chess.fromFEN(match.currentFen);
    final piece = chess.get(from);
    final isPawn = piece?.type.name.toLowerCase() == 'p';
    final isPromotionRank = (match.activeTurn == 'w' && to.endsWith('8')) ||
        (match.activeTurn == 'b' && to.endsWith('1'));

    String? promotionChoice;
    if (isPawn && isPromotionRank) {
      promotionChoice = await _showPromotionDialog();
      if (promotionChoice == null) return;
    }

    try {
      _lastMoveFrom = from;
      _lastMoveTo = to;

      await ref.read(gameStateNotifierProvider.notifier).executeMove(
            from,
            to,
            promotion: promotionChoice,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: BoardThemes.dangerAlert,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<String?> _showPromotionDialog() async {
    return PiecePromotionSheet.show(
      context,
      isWhite: ref.read(gameStateNotifierProvider).value?.activeTurn == 'w',
    );
  }

  // _buildPromotionOption is obsolete now




  void _showGameOverDialog(ChessMatch match) {
    final isDraw = match.status.name.startsWith('draw');

    String title;
    Color accentColor;
    if (isDraw) {
      title = 'Match Drawn (${match.status.name})';
      accentColor = BoardThemes.accentGold;
    } else {
      title = 'Match Over (${match.status.name})';
      accentColor = BoardThemes.accentEmerald;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: BoardThemes.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: accentColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Match completed with status: ${match.status.name}',
                textAlign: TextAlign.center,
                style: BoardThemes.bodyRegular,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      final moves = ref.read(matchMovesProvider(widget.matchId)).value ?? [];
                      final pgn = PgnService.generatePgn(
                        match: match,
                        moves: moves,
                      );
                      await PgnService.copyPgnToClipboard(pgn);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('PGN copied to clipboard!'),
                            backgroundColor: BoardThemes.pureWhite,
                          ),
                        );
                      }
                    },
                    child: const Text('[COPY PGN]', style: TextStyle(color: BoardThemes.pureWhite)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BoardThemes.accentCyan,
                      foregroundColor: BoardThemes.pitchBlack,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                    child: const Text('Lobby'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDashboard(
    ChessMatch match, {
    required bool isTopPlayer,
    required double boardRotationAngle,
  }) {
    // If auto-rotate is on, the top player is the one whose turn it is NOT.
    // In fixed mode (White on bottom), top player is Black.
    final bool isWhitePlayer = _autoRotate
        ? (match.activeTurn == 'w' ? !isTopPlayer : isTopPlayer)
        : !isTopPlayer;

    final dashWidget = LiquidGlassContainer(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.symmetric(vertical: 8),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          GameClockWidget(
            whiteMillisRemaining: match.whiteMillisRemaining ?? 0,
            blackMillisRemaining: match.blackMillisRemaining ?? 0,
            activeTurn: match.activeTurn,
            isMatchActive: match.isActive,
            playerName: isWhitePlayer ? 'White' : 'Black',
            opponentName: '', // Unused in this layout logic tweak
            playerColor: isWhitePlayer ? 'w' : 'b',
            onTimeout: () {
              ref.read(gameStateNotifierProvider.notifier).claimTimeout(match.activeTurn);
            },
          ),
          const SizedBox(height: 6),
          CapturedPiecesTray(
            fen: match.currentFen,
            isWhitePlayer: isWhitePlayer,
          ),
        ],
      ),
    );

    // If it's the top dashboard, rotate it 180 degrees so the top player can read it
    if (isTopPlayer) {
      return Transform.rotate(
        angle: math.pi,
        child: dashWidget,
      );
    }
    return dashWidget;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<ChessMatch>>(gameStateNotifierProvider, (previous, next) {
      final prevMatch = previous?.value;
      final nextMatch = next.value;
      if (prevMatch != null && nextMatch != null) {
        if (prevMatch.isActive && !nextMatch.isActive) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showGameOverDialog(nextMatch);
            }
          });
        }
      }
    });

    final matchAsync = ref.watch(gameStateNotifierProvider);
    final audioService = ref.watch(audioServiceProvider);

    return Scaffold(
      backgroundColor: BoardThemes.scaffoldBackground,
      appBar: AppBar(
        title: Text('MATCH', style: AppTypography.titleMedium),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.history),
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: matchAsync.value != null ? MoveHistoryPane(
        moves: ref.read(matchMovesProvider(matchAsync.value!.matchId)).value ?? [],
      ) : null,
      body: matchAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text(
            'Error loading match: $err',
            style: const TextStyle(color: BoardThemes.dangerAlert),
          ),
        ),
        data: (match) {
          final isKingInCheck =
              ref.read(gameStateNotifierProvider.notifier).isKingInCheck();
          final kingSquare =
              ref.read(gameStateNotifierProvider.notifier).getActiveKingSquare();

          final boardMap = _parseFenToBoardMap(match.currentFen);
          
          double boardRotationAngle = 0.0;
          if (_autoRotate && match.activeTurn == 'b') {
            boardRotationAngle = math.pi;
          }

          return SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Dashboard
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildDashboard(match, isTopPlayer: true, boardRotationAngle: boardRotationAngle),
                ),

                // Center Action Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _autoRotate = !_autoRotate;
                        });
                      },
                      child: Text(
                        _autoRotate ? '[AUTO-ROTATE ON]' : '[AUTO-ROTATE OFF]',
                        style: TextStyle(
                          color: _autoRotate ? BoardThemes.accentCyan : BoardThemes.mutedSilver,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        audioService.toggleMute();
                        setState(() {});
                      },
                      child: Text(
                        audioService.isMuted ? '[UNMUTE]' : '[MUTE]',
                        style: const TextStyle(
                          color: BoardThemes.mutedSilver,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => ref.read(gameStateNotifierProvider.notifier).resign(),
                      child: const Text(
                        '[RESIGN]',
                        style: TextStyle(
                          color: BoardThemes.dangerAlert,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                // Chess Board
                Expanded(
                  child: Center(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final boardSize = constraints.maxWidth.clamp(260.0, 500.0);
                        return TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: boardRotationAngle),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeInOutBack,
                          builder: (context, angle, child) {
                            return Transform.rotate(
                              angle: angle,
                              child: Container(
                                width: boardSize,
                                height: boardSize,
                                decoration: BoxDecoration(
                                  border: Border.all(color: BoardThemes.borderSubtle, width: 3),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: BoardThemes.darkCharcoal,
                                      blurRadius: 16,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(5),
                                  child: GridView.builder(
                                    physics: const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 8,
                                    ),
                                    itemCount: 64,
                                    itemBuilder: (context, index) {
                                      final sq = BoardSquareWidget.indexToSquare(index);
                                      final pieceChar = boardMap[index];

                                      final isSelected = _selectedSquare == sq;
                                      final isLegalTarget = _legalDestinations.contains(sq);
                                      final isCapture = isLegalTarget && pieceChar != null;
                                      final isKingChecked =
                                          isKingInCheck && kingSquare == sq;
                                      final isFrom = _lastMoveFrom == sq;
                                      final isTo = _lastMoveTo == sq;

                                      return BoardSquareWidget(
                                        linearIndex: index,
                                        isFlipped: false, // The whole board is flipped via Transform.rotate
                                        pieceChar: pieceChar,
                                        isSelected: isSelected,
                                        isLegalTarget: isLegalTarget,
                                        isCaptureTarget: isCapture,
                                        isKingInCheck: isKingChecked,
                                        isLastMoveFrom: isFrom,
                                        isLastMoveTo: isTo,
                                        canDragPiece: match.isActive &&
                                            pieceChar != null &&
                                            ((match.activeTurn == 'w' &&
                                                    pieceChar == pieceChar.toUpperCase()) ||
                                                (match.activeTurn == 'b' &&
                                                    pieceChar == pieceChar.toLowerCase())),
                                        onTap: () => _onSquareTapped(sq, pieceChar, match),
                                        onPieceDropped: (draggedPiece) {
                                          if (_selectedSquare != null && _selectedSquare != sq) {
                                            _processMoveAttempt(_selectedSquare!, sq, match);
                                          }
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),

                // Bottom Dashboard
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildDashboard(match, isTopPlayer: false, boardRotationAngle: boardRotationAngle),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
