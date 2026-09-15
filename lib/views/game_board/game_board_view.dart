import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess/chess.dart' as chess_lib;
import '../../core/rules/material_calculator.dart';
import '../../core/theme/board_themes.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/liquid_glass.dart';
import '../../models/chess_match.dart';
import '../../services/audio_service.dart';
import '../../services/pgn_service.dart';
import '../../services/live_drag_service.dart';
import '../../services/settings_service.dart';
import '../../state/game_state_notifier.dart';
import 'package:enterprise_chess/views/dashboard/match_setup_screen.dart';
import 'widgets/board_square.dart';
import 'widgets/game_clock.dart';
import 'widgets/evaluation_bar.dart';
import 'widgets/quick_chat_modal.dart';
import 'widgets/chess_piece.dart';
import 'board_3d/chess_scene_controller.dart';
import 'board_3d/move_animation_controller.dart';
import 'board_3d/board_3d_view.dart';
import '../widgets/loading_overlay.dart';
import '../../core/errors/error_boundary.dart';

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
  String? _activeReaction;

  late ChessSceneController _sceneController;
  late MoveAnimationController _moveAnimationController;
  final GlobalKey _boardKey = GlobalKey();

  DatabaseReference? _presenceRef;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _sceneController = ChessSceneController();
    _moveAnimationController = MoveAnimationController();

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (mounted) {
        setState(() => _isOffline = results.contains(ConnectivityResult.none));
      }
    });
    Connectivity().checkConnectivity().then((results) {
      if (mounted) {
        setState(() => _isOffline = results.contains(ConnectivityResult.none));
      }
    });

    // Activate match subscription in Riverpod notifier
    Future.microtask(() {
      final currentUid = ref.read(authServiceProvider).currentUid;
      if (currentUid.isNotEmpty) {
        _presenceRef = FirebaseDatabase.instance.ref('presence/\${widget.matchId}/$currentUid');
        _presenceRef!.set(true);
        _presenceRef!.onDisconnect().remove();
      }
      ref.read(gameStateNotifierProvider.notifier).setActiveMatch(widget.matchId);
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _presenceRef?.remove();
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

  void _onPieceDragUpdate(String fromSquare, DragUpdateDetails details) {
    if (_boardKey.currentContext == null) return;
    final RenderBox box = _boardKey.currentContext!.findRenderObject() as RenderBox;
    final localPos = box.globalToLocal(details.globalPosition);
    final currentUid = ref.read(authServiceProvider).currentUid;
    final x = (localPos.dx / box.size.width).clamp(0.0, 1.0);
    final y = (localPos.dy / box.size.height).clamp(0.0, 1.0);
    ref.read(liveDragServiceProvider).updateDrag(widget.matchId, currentUid, fromSquare, x, y);
  }

  void _onPieceDragEnd(String fromSquare) {
    ref.read(liveDragServiceProvider).clearDrag(widget.matchId);
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

      if (ref.read(render3dProvider) && piece != null) {
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
            style: TextStyle(color: BoardThemes.pureWhite, fontWeight: FontWeight.bold),
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
          style: AppTypography.bodyRegular,
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
                            backgroundColor: BoardThemes.pureWhite, // Switched to greyscale
                          ),
                        );
                      }
                    },
                    child: const Text('[COPY PGN]', style: TextStyle(color: BoardThemes.pureWhite)), // No icons
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => MatchSetupScreen(matchType: match.matchType == 'engine' ? 'engine' : 'human'),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BoardThemes.brandEmber,
                      foregroundColor: BoardThemes.pitchBlack,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                    child: const Text('Rematch'),
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

  @override
  Widget build(BuildContext context) {
    // Automatically show the game over dialog when the match transitions to inactive.
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
    final movesAsync = ref.watch(matchMovesProvider(widget.matchId));
    final ghostStateAsync = ref.watch(liveDragStreamProvider(widget.matchId));
    final currentUid = ref.read(authServiceProvider).currentUid;
    
    final render3d = ref.watch(render3dProvider);
    final audioService = ref.watch(audioServiceProvider);

    return Scaffold(
      backgroundColor: BoardThemes.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: BoardThemes.surfaceDark,
        elevation: 0,
        title: Text(
          'Match: ${widget.matchId.length > 8 ? widget.matchId.substring(0, 8) : widget.matchId}',
          style: AppTypography.labelLarge,
        ),
        actions: [
          // ── Sound toggle chip ─────────────────────────────────────────
          _AppBarChip(
            label: audioService.isMuted ? 'Sound Off' : 'Sound',
            active: !audioService.isMuted,
            onTap: () {
              audioService.toggleMute();
              setState(() {}); // Re-render the chip
            },
          ),
          // ── 2D / 3D toggle chip ───────────────────────────────────────
          _AppBarChip(
            label: render3d ? '3D' : '2D',
            active: true,
            onTap: () {
              ref.read(render3dProvider.notifier).setRender3d(!render3d);
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
                  color: BoardThemes.mutedSilver,
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
                child: Text('Copy PGN', style: TextStyle(color: BoardThemes.pureWhite)),
              ),
              const PopupMenuItem(
                value: 'fen',
                child: Text('Copy FEN', style: TextStyle(color: BoardThemes.pureWhite)),
              ),
            ],
          ),
        ],
      ),
      body: matchAsync.when(
        loading: () => const LoadingOverlay(message: 'LOADING MATCH'),
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

          return Stack(
            children: [
              SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    // Top Clock Bar (Conditional)
                    if (match.isTimedMatch && match.whiteMillisRemaining != null && match.blackMillisRemaining != null)
                      LiquidGlassContainer(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        borderRadius: BorderRadius.circular(16),
                        child: Column(
                          children: [
                            if (match.timeControlPreset != null) ...[
                              Text(
                                match.timeControlPreset!,
                                style: const TextStyle(color: BoardThemes.mutedSilver, fontSize: 12),
                              ),
                              const SizedBox(height: 8),
                            ],
                            GameClockWidget(
                              whiteMillisRemaining: match.whiteMillisRemaining!,
                              blackMillisRemaining: match.blackMillisRemaining!,
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
                          ],
                        ),
                      )
                    else 
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Untimed Match',
                          style: BoardThemes.bodyRegular.copyWith(color: BoardThemes.mutedSilver),
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
                                    foregroundColor: BoardThemes.pureWhite,
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
                          boxShadow: const [BoxShadow(color: BoardThemes.darkCharcoal, blurRadius: 10)],
                        ),
                        child: Text(
                          _activeReaction!,
                          style: const TextStyle(
                            color: BoardThemes.pureWhite,
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
                        if (render3d) {
                          boardWidget = Container(
                            width: boardSize,
                            height: boardSize * 1.1,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: BoardThemes.borderSubtle, width: 2),
                              boxShadow: const [
                                BoxShadow(
                                  color: BoardThemes.midSlate,
                                  blurRadius: 18,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ErrorBoundary(
                              fallbackBuilder: (context, error, stackTrace) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  ref.read(render3dProvider.notifier).setRender3d(false);
                                });
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Text(
                                      "3D Engine Error, falling back to 2D...",
                                      style: TextStyle(color: BoardThemes.dangerAlert),
                                    ),
                                  ),
                                );
                              },
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
                                  ref.read(render3dProvider.notifier).setRender3d(false);
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
                            ),
                          );
                        } else {
                          final ghostState = ghostStateAsync.value;
                          boardWidget = Container(
                            key: _boardKey,
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
                                    onDragUpdate: _onPieceDragUpdate,
                                    onDragEnd: _onPieceDragEnd,
                                  );
                                },
                              ),
                            ),
                          );

                          // Overlay Ghost Piece if active
                          if (ghostState != null) {
                            final chess = chess_lib.Chess.fromFEN(match.currentFen);
                            final ghostPiece = chess.get(ghostState.fromSquare);
                            if (ghostPiece != null) {
                              final pieceChar = ghostPiece.color == chess_lib.Color.WHITE
                                  ? ghostPiece.type.name.toUpperCase()
                                  : ghostPiece.type.name.toLowerCase();
                              
                              final ghostSize = boardSize / 8.0;
                              final gx = ghostState.x * boardSize - (ghostSize / 2);
                              final gy = ghostState.y * boardSize - (ghostSize / 2);

                              boardWidget = Stack(
                                children: [
                                  boardWidget,
                                  Positioned(
                                    left: gx,
                                    top: gy,
                                    width: ghostSize,
                                    height: ghostSize,
                                    child: IgnorePointer(
                                      child: ChessPieceWidget(
                                        pieceChar: pieceChar,
                                        isGhost: true,
                                        size: ghostSize * 0.8,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }
                          }
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
                              height: boardSize * (render3d ? 1.1 : 1.0),
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
                          ElevatedButton(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                builder: (context) => QuickChatModal(
                                  onSelected: _onReactionSelected,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: BoardThemes.surfaceCard,
                              foregroundColor: BoardThemes.pureWhite,
                            ),
                            child: const Text('CHAT'),
                          ),
                          ElevatedButton(
                            onPressed: () =>
                                ref.read(gameStateNotifierProvider.notifier).offerDraw(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: BoardThemes.surfaceCard,
                              foregroundColor: BoardThemes.pureWhite,
                            ),
                            child: const Text('OFFER DRAW'),
                          ),
                          ElevatedButton(
                            onPressed: () =>
                                ref.read(gameStateNotifierProvider.notifier).resign(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: BoardThemes.dangerAlert.withAlpha(200),
                              foregroundColor: BoardThemes.pureWhite,
                            ),
                            child: const Text('RESIGN'),
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
                                foregroundColor: BoardThemes.pitchBlack,
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
                                      color: BoardThemes.pureWhite,
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
              ),
              if (_isOffline)
                Positioned.fill(
                  child: Container(
                    color: BoardThemes.midSlate,
                    child: Center(
                      child: LiquidGlassContainer(
                        padding: const EdgeInsets.all(24),
                        borderRadius: BorderRadius.circular(16),
                        child: const Text('Reconnecting...', style: TextStyle(color: BoardThemes.pureWhite, fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
            ],
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
