import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess/chess.dart' as chess_lib;
import '../../core/rules/material_calculator.dart';
import '../../core/theme/board_themes.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/liquid_glass.dart';
import '../../models/chess_match.dart';
import '../../services/audio_service.dart';
import '../../services/pgn_service.dart';
import '../../state/game_state_notifier.dart';
import 'widgets/board_square.dart';
import 'widgets/game_clock.dart';
import 'widgets/evaluation_bar.dart';
import 'widgets/quick_chat_modal.dart';
import 'board_3d/chess_scene_controller.dart';
import 'board_3d/move_animation_controller.dart';
import 'board_3d/board_3d_view.dart';

/// Interactive chess board supporting both high-performance 2D and perspective 3D rendering with live fallback.
class GameBoardView extends ConsumerStatefulWidget {
  final String matchId;

  const GameBoardView({
    super.key,
    required this.matchId,
  });

  @override
  ConsumerState<GameBoardView> createState() => _GameBoardViewState();
}

class _GameBoardViewState extends ConsumerState<GameBoardView> {
  String? _selectedSquare;
  List<String> _legalDestinations = [];
  bool _isBoardFlipped = false;
  String? _lastMoveFrom;
  String? _lastMoveTo;
  BoardRenderMode _renderMode = BoardRenderMode.twoD;
  String? _activeReaction;
  bool _isAudioMuted = false;

  late ChessSceneController _sceneController;
  late MoveAnimationController _moveAnimationController;

  @override
  void initState() {
    super.initState();
    _sceneController = ChessSceneController();
    _moveAnimationController = MoveAnimationController();

    // Activate match subscription in Riverpod notifier
    Future.microtask(() {
      ref.read(gameStateNotifierProvider.notifier).setActiveMatch(widget.matchId);
    });
  }

  @override
  void dispose() {
    _sceneController.dispose();
    _moveAnimationController.dispose();
    super.dispose();
  }

  /// Parses FEN string into a 64-element piece map (0..63).
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

    final currentUid = ref.read(authServiceProvider).currentUid;
    final isWhiteTurn = match.activeTurn == 'w';

    // Disallow moving out of turn
    if (match.matchType == 'human') {
      if (isWhiteTurn && match.whiteUid != currentUid) return;
      if (!isWhiteTurn && match.blackUid != currentUid) return;
    }

    if (_selectedSquare != null) {
      if (_legalDestinations.contains(square)) {
        // Legal move clicked
        _processMoveAttempt(_selectedSquare!, square, match);
        setState(() {
          _selectedSquare = null;
          _legalDestinations = [];
        });
        return;
      }
    }

    // Select piece if it belongs to current player
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

    // Clear selection on empty or invalid square tap
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

      if (_renderMode == BoardRenderMode.threeD && piece != null) {
        final movingPieceChar = piece.color == chess_lib.Color.WHITE
            ? piece.type.name.toUpperCase()
            : piece.type.name.toLowerCase();
        _moveAnimationController.startMoveAnimation(
          pieceChar: movingPieceChar,
          fromSquare: from,
          toSquare: to,
        );
      }

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
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: BoardThemes.surfaceCard,
          title: const Text(
            'Promote Pawn',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPromotionOption('q', '♛ Queen'),
              _buildPromotionOption('r', '♜ Rook'),
              _buildPromotionOption('b', '♝ Bishop'),
              _buildPromotionOption('n', '♞ Knight'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPromotionOption(String pieceCode, String label) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(pieceCode),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: BoardThemes.surfaceDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: BoardThemes.borderSubtle),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.white),
        ),
      ),
    );
  }

  void _onReactionSelected(String message, bool isEmote) {
    setState(() {
      _activeReaction = message;
    });
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted && _activeReaction == message) {
        setState(() => _activeReaction = null);
      }
    });
  }

  Widget _buildCapturedTray(List<String> pieces, int advantage, bool isWhite) {
    if (pieces.isEmpty && advantage <= 0) {
      return const SizedBox(height: 18);
    }
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: pieces.map((p) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Text(
                      MaterialScore.getPieceSymbol(p),
                      style: TextStyle(
                        fontSize: 16,
                        color: isWhite ? const Color(0xFFF0D9B5) : const Color(0xFF94A3B8),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          if (advantage > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: BoardThemes.accentCyan.withAlpha(40),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '+$advantage',
                style: const TextStyle(
                  color: BoardThemes.accentCyan,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showGameOverDialog(ChessMatch match) {
    final currentUid = ref.read(authServiceProvider).currentUid;
    final isWinner = match.winnerUid == currentUid;
    final isDraw = match.status.name.startsWith('draw');

    String title;
    Color accentColor;
    if (isDraw) {
      title = 'Match Drawn (${match.status.name})';
      accentColor = BoardThemes.accentGold;
    } else if (isWinner) {
      title = 'Victory! (${match.status.name})';
      accentColor = BoardThemes.accentEmerald;
    } else {
      title = 'Defeat (${match.status.name})';
      accentColor = BoardThemes.dangerAlert;
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
                  OutlinedButton.icon(
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
                            backgroundColor: BoardThemes.accentEmerald,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy, size: 16, color: BoardThemes.accentCyan),
                    label: const Text('Copy PGN', style: TextStyle(color: BoardThemes.accentCyan)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BoardThemes.accentCyan,
                      foregroundColor: Colors.black,
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

  @override
  Widget build(BuildContext context) {
    final matchAsync = ref.watch(gameStateNotifierProvider);
    final movesAsync = ref.watch(matchMovesProvider(widget.matchId));
    final currentUid = ref.read(authServiceProvider).currentUid;

    return Scaffold(
      backgroundColor: BoardThemes.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: BoardThemes.surfaceDark,
        elevation: 0,
        title: Text(
          'Match: ${widget.matchId.length > 8 ? widget.matchId.substring(0, 8) : widget.matchId}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          // ── Sound toggle chip ─────────────────────────────────────────
          _AppBarChip(
            label: _isAudioMuted ? 'Sound Off' : 'Sound',
            active: !_isAudioMuted,
            onTap: () {
              ref.read(audioServiceProvider).toggleMute();
              setState(() => _isAudioMuted = !_isAudioMuted);
            },
          ),
          // ── 2D / 3D toggle chip ───────────────────────────────────────
          _AppBarChip(
            label: _renderMode == BoardRenderMode.threeD ? '3D' : '2D',
            active: true,
            onTap: () {
              setState(() {
                _renderMode = _renderMode == BoardRenderMode.threeD
                    ? BoardRenderMode.twoD
                    : BoardRenderMode.threeD;
              });
            },
          ),
          // ── Flip board chip ───────────────────────────────────────────
          _AppBarChip(
            label: 'Flip',
            active: _isBoardFlipped,
            onTap: () {
              setState(() {
                _isBoardFlipped = !_isBoardFlipped;
                _sceneController.isFlipped = _isBoardFlipped;
              });
            },
          ),
          // ── Overflow menu chip (PGN / FEN export) ─────────────────────
          PopupMenuButton<String>(
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            onSelected: (value) async {
              final currentMatch = matchAsync.value;
              if (currentMatch == null) return;
              if (value == 'pgn') {
                final moves = movesAsync.value ?? [];
                final pgn = PgnService.generatePgn(
                  match: currentMatch,
                  moves: moves,
                );
                await PgnService.copyPgnToClipboard(pgn);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('PGN copied to clipboard!'),
                      backgroundColor: BoardThemes.accentEmerald,
                    ),
                  );
                }
              } else if (value == 'fen') {
                await PgnService.copyFenToClipboard(currentMatch.currentFen);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('FEN copied to clipboard!'),
                      backgroundColor: BoardThemes.accentEmerald,
                    ),
                  );
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'pgn',
                child: Text('Copy PGN', style: TextStyle(color: Colors.white)),
              ),
              const PopupMenuItem(
                value: 'fen',
                child: Text('Copy FEN', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
      body: matchAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: BoardThemes.accentCyan),
        ),
        error: (err, stack) => Center(
          child: Text(
            'Error loading match: $err',
            style: const TextStyle(color: BoardThemes.dangerAlert),
          ),
        ),
        data: (match) {
          final isPlayerWhite = match.whiteUid == currentUid;
          final isKingInCheck =
              ref.read(gameStateNotifierProvider.notifier).isKingInCheck();
          final kingSquare =
              ref.read(gameStateNotifierProvider.notifier).getActiveKingSquare();

          final boardMap = _parseFenToBoardMap(match.currentFen);
          final material = MaterialScore.fromFen(match.currentFen);
          final playerCaptured = isPlayerWhite
              ? material.whiteCapturedPieces
              : material.blackCapturedPieces;
          final opponentCaptured = isPlayerWhite
              ? material.blackCapturedPieces
              : material.whiteCapturedPieces;
          final playerAdvantage =
              isPlayerWhite ? material.whiteAdvantage : material.blackAdvantage;
          final opponentAdvantage =
              isPlayerWhite ? material.blackAdvantage : material.whiteAdvantage;

          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    // Top Clock Bar
                    LiquidGlassContainer(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      borderRadius: BorderRadius.circular(16),
                      child: GameClockWidget(
                        whiteMillisRemaining: match.whiteMillisRemaining,
                        blackMillisRemaining: match.blackMillisRemaining,
                        activeTurn: match.activeTurn,
                        isMatchActive: match.isActive,
                        playerName: isPlayerWhite ? 'You (White)' : 'You (Black)',
                        opponentName: match.matchType == 'engine'
                            ? 'Stockfish (Lv ${match.engineDifficulty ?? 10})'
                            : (isPlayerWhite ? 'Opponent (Black)' : 'Opponent (White)'),
                        playerColor: isPlayerWhite ? 'w' : 'b',
                        onTimeout: () {
                          ref
                              .read(gameStateNotifierProvider.notifier)
                              .claimTimeout(match.activeTurn);
                        },
                      ),
                    ),

                    // Draw Offer Notification Banner
                    if (match.drawOfferedBy != null &&
                        match.drawOfferedBy != currentUid &&
                        match.isActive)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: BoardThemes.accentGold.withAlpha(30),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: BoardThemes.accentGold),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Opponent offered a draw',
                              style: TextStyle(color: BoardThemes.accentGold, fontWeight: FontWeight.bold),
                            ),
                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: () => ref
                                      .read(gameStateNotifierProvider.notifier)
                                      .respondToDraw(true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: BoardThemes.accentEmerald,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                  ),
                                  child: const Text('Accept'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () => ref
                                      .read(gameStateNotifierProvider.notifier)
                                      .respondToDraw(false),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                  ),
                                  child: const Text('Decline'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                    // Reaction Floating Banner
                    if (_activeReaction != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: BoardThemes.surfaceCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: BoardThemes.accentCyan),
                          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
                        ),
                        child: Text(
                          _activeReaction!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                    // Top Opponent Captured Pieces Tray
                    _buildCapturedTray(opponentCaptured, opponentAdvantage, !isPlayerWhite),
                    const SizedBox(height: 6),

                    // Chess Board: 3D or 2D with Live Evaluation Bar
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final availableWidth = constraints.maxWidth - 34.0;
                        final boardSize = availableWidth.clamp(260.0, 500.0);

                        Widget boardWidget;
                        if (_renderMode == BoardRenderMode.threeD) {
                          boardWidget = Container(
                            width: boardSize,
                            height: boardSize * 1.1,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: BoardThemes.borderSubtle, width: 2),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black54,
                                  blurRadius: 18,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Board3DView(
                                fen: match.currentFen,
                                selectedSquare: _selectedSquare,
                                legalDestinations: _legalDestinations,
                                lastMoveFrom: _lastMoveFrom,
                                lastMoveTo: _lastMoveTo,
                                kingInCheckSquare: isKingInCheck ? kingSquare : null,
                                isFlipped: _isBoardFlipped,
                                sceneController: _sceneController,
                                animationController: _moveAnimationController,
                                onFallbackTo2D: () {
                                  setState(() {
                                    _renderMode = BoardRenderMode.twoD;
                                  });
                                },
                                onSquareTap: (square) {
                                  final chess = chess_lib.Chess.fromFEN(match.currentFen);
                                  final piece = chess.get(square);
                                  final pieceChar = piece != null
                                      ? (piece.color == chess_lib.Color.WHITE
                                          ? piece.type.name.toUpperCase()
                                          : piece.type.name.toLowerCase())
                                      : null;
                                  _onSquareTapped(square, pieceChar, match);
                                },
                              ),
                            ),
                          );
                        } else {
                          boardWidget = Container(
                            width: boardSize,
                            height: boardSize,
                            decoration: BoxDecoration(
                              border: Border.all(color: BoardThemes.borderSubtle, width: 3),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black45,
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
                                  final effectiveIndex =
                                      _isBoardFlipped ? (63 - index) : index;
                                  final sq = BoardSquareWidget.indexToSquare(effectiveIndex);
                                  final pieceChar = boardMap[effectiveIndex];

                                  final isSelected = _selectedSquare == sq;
                                  final isLegalTarget = _legalDestinations.contains(sq);
                                  final isCapture = isLegalTarget && pieceChar != null;
                                  final isKingChecked =
                                      isKingInCheck && kingSquare == sq;
                                  final isFrom = _lastMoveFrom == sq;
                                  final isTo = _lastMoveTo == sq;

                                  return BoardSquareWidget(
                                    linearIndex: index,
                                    isFlipped: _isBoardFlipped,
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
                          );
                        }

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            EvaluationBar(
                              centipawns: match.matchType == 'engine'
                                  ? (isPlayerWhite
                                      ? (material.whiteAdvantage * 100.0)
                                      : (material.blackAdvantage * 100.0))
                                  : (isPlayerWhite
                                      ? (material.whiteAdvantage * 75.0)
                                      : (material.blackAdvantage * 75.0)),
                              isWhiteOrientation: !_isBoardFlipped,
                              height: boardSize * (_renderMode == BoardRenderMode.threeD ? 1.1 : 1.0),
                            ),
                            const SizedBox(width: 8),
                            boardWidget,
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 6),
                    // Bottom Player Captured Pieces Tray
                    _buildCapturedTray(playerCaptured, playerAdvantage, isPlayerWhite),
                    const SizedBox(height: 14),

                    // Controls Bar (Chat, Offer Draw, Resign)
                    if (match.isActive)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                builder: (context) => QuickChatModal(
                                  onSelected: _onReactionSelected,
                                ),
                              );
                            },
                            icon: const Icon(Icons.chat_bubble_outline, size: 18),
                            label: const Text('Chat'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: BoardThemes.surfaceCard,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () =>
                                ref.read(gameStateNotifierProvider.notifier).offerDraw(),
                            icon: const Icon(Icons.handshake_outlined, size: 18),
                            label: const Text('Offer Draw'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: BoardThemes.surfaceCard,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () =>
                                ref.read(gameStateNotifierProvider.notifier).resign(),
                            icon: const Icon(Icons.flag_outlined, size: 18),
                            label: const Text('Resign'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: BoardThemes.dangerAlert.withAlpha(200),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: BoardThemes.surfaceCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: BoardThemes.borderSubtle),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Status: ${match.status.name}',
                              style: const TextStyle(
                                color: BoardThemes.accentGold,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => _showGameOverDialog(match),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: BoardThemes.accentCyan,
                                foregroundColor: Colors.black,
                              ),
                              child: const Text('Summary'),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Move History Horizontal Tray
                    movesAsync.when(
                      data: (moves) {
                        if (moves.isEmpty) return const SizedBox.shrink();
                        return Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: BoardThemes.surfaceDark,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: BoardThemes.borderSubtle),
                          ),
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: moves.length,
                            separatorBuilder: (context, i) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final m = moves[index];
                              return Center(
                                child: Chip(
                                  backgroundColor: BoardThemes.surfaceCard,
                                  label: Text(
                                    '${m.moveNumber}. ${m.san}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
        loading: () => const SizedBox.shrink(),
                      error: (e, st) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AppBarChip — compact text pill used in the zero-icon AppBar.
// ─────────────────────────────────────────────────────────────────────────────

class _AppBarChip extends StatelessWidget {
  const _AppBarChip({
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final String label;
  final VoidCallback onTap;

  /// When true, draws a 1 px white border to signal the active state.
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: active
                ? BoardThemes.pureWhite.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: active
                ? Border.all(color: BoardThemes.pureWhite.withValues(alpha: 0.30), width: 1)
                : null,
          ),
          child: Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              color: active ? BoardThemes.pureWhite : BoardThemes.mutedSilver,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
