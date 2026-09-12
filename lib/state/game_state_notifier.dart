import 'dart:async';
import 'package:chess/chess.dart' as chess_lib;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/constants/chess_constants.dart';
import '../core/errors/app_exceptions.dart';
import '../core/rules/chess_rules_evaluator.dart';
import '../models/chess_match.dart';
import '../models/chess_move.dart';
import '../services/firebase_auth_service.dart';
import '../services/firestore_service.dart';
import '../services/stockfish_service.dart';

/// Global provider for FirebaseAuthService.
final authServiceProvider = Provider<FirebaseAuthService>((ref) {
  return FirebaseAuthService();
});

/// Global provider for FirestoreService.
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

/// Notifier tracking the active match ID.
class ActiveMatchIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setMatchId(String? id) => state = id;
}

/// Provider tracking the active match ID.
final activeMatchIdProvider =
    NotifierProvider<ActiveMatchIdNotifier, String?>(ActiveMatchIdNotifier.new);

/// Provider for active match move history.
final matchMovesProvider =
    StreamProvider.family<List<ChessMove>, String>((ref, matchId) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getMovesStream(matchId);
});

/// Notifier indicating if an active move transaction is currently in-flight.
class IsMoveInFlightNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool val) => state = val;
}

final isMoveInFlightProvider =
    NotifierProvider<IsMoveInFlightNotifier, bool>(IsMoveInFlightNotifier.new);

/// Notifier indicating if the real-time stream is currently reconnecting.
class IsReconnectingNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool val) => state = val;
}

final isReconnectingProvider =
    NotifierProvider<IsReconnectingNotifier, bool>(IsReconnectingNotifier.new);

/// Riverpod AsyncNotifier managing live chess match lifecycle and moves.
final gameStateNotifierProvider =
    AsyncNotifierProvider<GameStateNotifier, ChessMatch>(
  GameStateNotifier.new,
);

class GameStateNotifier extends AsyncNotifier<ChessMatch> {
  StreamSubscription<ChessMatch?>? _matchSubscription;
  late FirestoreService _firestoreService;
  late FirebaseAuthService _authService;
  late StockfishService _stockfishService;
  int _reconnectAttempts = 0;

  @override
  Future<ChessMatch> build() async {
    _firestoreService = ref.watch(firestoreServiceProvider);
    _authService = ref.watch(authServiceProvider);
    _stockfishService = StockfishService.instance;

    final matchId = ref.watch(activeMatchIdProvider);
    if (matchId == null || matchId.isEmpty) {
      final now = DateTime.now();
      return ChessMatch(
        matchId: '',
        whiteUid: '',
        blackUid: '',
        currentFen: ChessConstants.initialFen,
        status: MatchStatus.active,
        activeTurn: 'w',
        whiteMillisRemaining: ChessConstants.rapidMillis,
        blackMillisRemaining: ChessConstants.rapidMillis,
        lastMoveServerTimestamp: now,
        createdAt: now,
        matchType: 'human',
      );
    }

    _subscribeToMatchStream(matchId);

    ref.onDispose(() {
      _matchSubscription?.cancel();
    });

    final initialStream = _firestoreService.getMatchStream(matchId);
    final initialMatch = await initialStream.first;
    if (initialMatch == null) {
      throw StateError('Match $matchId not found');
    }
    return initialMatch;
  }

  void _subscribeToMatchStream(String matchId) {
    _matchSubscription?.cancel();
    _matchSubscription = _firestoreService.getMatchStream(matchId).listen(
      (updatedMatch) {
        if (updatedMatch != null) {
          _reconnectAttempts = 0;
          ref.read(isReconnectingProvider.notifier).state = false;
          state = AsyncData(updatedMatch);

          // If single player vs engine and it's engine's turn, trigger engine evaluation
          if (updatedMatch.matchType == 'engine' &&
              updatedMatch.isActive &&
              updatedMatch.activeTurn == 'b') {
            _triggerEngineMove(updatedMatch);
          }
        }
      },
      onError: (err, stack) {
        handleReconnect();
      },
    );
  }

  /// Sets the active match ID to subscribe to.
  void setActiveMatch(String matchId) {
    ref.read(activeMatchIdProvider.notifier).setMatchId(matchId);
  }

  /// Reconciles local state on connection loss with exponential backoff.
  Future<void> handleReconnect() async {
    ref.read(isReconnectingProvider.notifier).state = true;
    _reconnectAttempts++;
    final backoffSeconds = (1 << _reconnectAttempts.clamp(1, 5));

    await Future.delayed(Duration(seconds: backoffSeconds));

    final matchId = ref.read(activeMatchIdProvider);
    if (matchId != null && matchId.isNotEmpty) {
      _subscribeToMatchStream(matchId);
    }
  }

  /// Calculates legal destination squares for a selected square in the current position.
  List<String> getLegalDestinations(String square) {
    final currentMatch = state.value;
    if (currentMatch == null) return [];

    final chess = chess_lib.Chess.fromFEN(currentMatch.currentFen);
    final moves = chess.moves({
      'square': square.toLowerCase(),
      'verbose': true,
    });

    final destinations = <String>[];
    for (final m in moves) {
      if (m is Map) {
        final to = m['to']?.toString();
        if (to != null) destinations.add(to);
      }
    }
    return destinations;
  }

  /// Checks if king of the active player is in check.
  bool isKingInCheck() {
    final currentMatch = state.value;
    if (currentMatch == null) return false;
    final chess = chess_lib.Chess.fromFEN(currentMatch.currentFen);
    return chess.in_check;
  }

  /// Locates the square of the active king (e.g. 'e1' or 'e8').
  String? getActiveKingSquare() {
    final currentMatch = state.value;
    if (currentMatch == null) return null;

    final chess = chess_lib.Chess.fromFEN(currentMatch.currentFen);
    final targetPiece = currentMatch.activeTurn == 'w' ? 'K' : 'k';

    for (int rank = 8; rank >= 1; rank--) {
      for (int file = 0; file < 8; file++) {
        final fileChar = String.fromCharCode('a'.codeUnitAt(0) + file);
        final sq = '$fileChar$rank';
        final piece = chess.get(sq);
        if (piece != null) {
          final pieceChar = piece.color == chess_lib.Color.WHITE
              ? piece.type.name.toUpperCase()
              : piece.type.name.toLowerCase();
          if (pieceChar == targetPiece) {
            return sq;
          }
        }
      }
    }
    return null;
  }

  /// Executes a chess move with client idempotency ID, local verification, and atomic Firestore commit.
  Future<void> executeMove(
    String fromSquare,
    String toSquare, {
    String? promotion,
  }) async {
    // 1. Generate clientMoveId (UUIDv4) immediately before anything else
    final clientMoveId = const Uuid().v4();

    final currentMatch = state.value;
    if (currentMatch == null) {
      throw const StaleStateException('No active match state found.', clientFen: '', serverFen: '');
    }

    if (!currentMatch.isActive) {
      throw StateError('Match is already concluded (${currentMatch.status.name}).');
    }

    final currentUid = _authService.currentUid;
    final isWhiteTurn = currentMatch.activeTurn == 'w';

    // Verify player authorization
    if (currentMatch.matchType == 'human') {
      if (isWhiteTurn && currentMatch.whiteUid != currentUid) {
        throw OutOfTurnException(
          "It is White's turn, but caller is not White.",
          expectedColor: 'w',
          attemptingUid: currentUid,
        );
      }
      if (!isWhiteTurn && currentMatch.blackUid != currentUid) {
        throw OutOfTurnException(
          "It is Black's turn, but caller is not Black.",
          expectedColor: 'b',
          attemptingUid: currentUid,
        );
      }
    }

    // Step 2: Validate locally via pure Dart chess engine
    final chessGame = chess_lib.Chess.fromFEN(currentMatch.currentFen);
    final from = fromSquare.toLowerCase();
    final to = toSquare.toLowerCase();
    final promo = promotion?.toLowerCase();

    // Check if moving piece is a pawn or if destination has a captured piece (for 50-move halfmove clock reset)
    final movingPiece = chessGame.get(from);
    final isPawnMove = movingPiece?.type.name.toLowerCase() == 'p';
    final targetPiece = chessGame.get(to);
    final isCapture = targetPiece != null;

    final moveOptions = <String, dynamic>{
      'from': from,
      'to': to,
    };
    if (promo != null) {
      moveOptions['promotion'] = promo;
    }

    final moveSuccess = chessGame.move(moveOptions);
    if (!moveSuccess) {
      throw IllegalMoveException(
        'Illegal chess move from $from to $to',
        from: from,
        to: to,
        fen: currentMatch.currentFen,
      );
    }

    // Step 3: Compute new board state & exhaustive draw flags
    final newFen = chessGame.fen;
    final san = chessGame.history.isNotEmpty
        ? chessGame.history.last.toString()
        : '$from-$to';
    final isCheck = chessGame.in_check;
    final isCheckmate = chessGame.in_checkmate;
    final isStalemate = chessGame.in_stalemate;

    // Position history for exact threefold repetition
    final updatedPositionHistory = List<String>.from(currentMatch.positionHistory)..add(newFen);
    final isThreefold = ChessRulesEvaluator.isThreefoldRepetition(newFen, updatedPositionHistory);

    // Halfmove clock for 50-move rule
    final updatedHalfmoveClock = (isPawnMove || isCapture) ? 0 : (currentMatch.halfmoveClock + 1);
    final is50Move = updatedHalfmoveClock >= 100;

    // Insufficient material evaluation (covers all 4 cases)
    final isInsufficient = ChessRulesEvaluator.isInsufficientMaterial(chessGame);

    MatchStatus newStatus = MatchStatus.active;
    if (isCheckmate) {
      newStatus = isWhiteTurn
          ? MatchStatus.whiteWonCheckmate
          : MatchStatus.blackWonCheckmate;
    } else if (isStalemate) {
      newStatus = MatchStatus.drawStalemate;
    } else if (isThreefold) {
      newStatus = MatchStatus.drawThreefoldRepetition;
    } else if (is50Move) {
      newStatus = MatchStatus.drawFiftyMoveRule;
    } else if (isInsufficient) {
      newStatus = MatchStatus.drawInsufficientMaterial;
    }

    final moveNumber = chessGame.history.length;

    // Set in-flight lock
    ref.read(isMoveInFlightProvider.notifier).state = true;

    // Step 4: Run Firestore atomic transaction with idempotency guard
    try {
      await _firestoreService.submitMoveTransaction(
        matchId: currentMatch.matchId,
        playerUid: currentMatch.matchType == 'engine' && !isWhiteTurn
            ? 'engine_stockfish'
            : currentUid,
        newFen: newFen,
        san: san,
        moveNumber: moveNumber,
        isCheck: isCheck,
        isCheckmate: isCheckmate,
        newStatus: newStatus,
        clientMoveId: clientMoveId,
        updatedHalfmoveClock: updatedHalfmoveClock,
        promotionPiece: promo,
      );

      // Optimistic state update for instant visual feedback
      state = AsyncData(
        currentMatch.copyWith(
          currentFen: newFen,
          activeTurn: isWhiteTurn ? 'b' : 'w',
          status: newStatus,
          lastMoveSan: san,
          moveCount: currentMatch.moveCount + 1,
          positionHistory: updatedPositionHistory,
          halfmoveClock: updatedHalfmoveClock,
          processedClientMoveIds: List<String>.from(currentMatch.processedClientMoveIds)..add(clientMoveId),
          winnerUid: newStatus == MatchStatus.whiteWonCheckmate
              ? currentMatch.whiteUid
              : (newStatus == MatchStatus.blackWonCheckmate
                  ? currentMatch.blackUid
                  : null),
        ),
      );
    } catch (e, stack) {
      state = AsyncError(e, stack);
      rethrow;
    } finally {
      ref.read(isMoveInFlightProvider.notifier).state = false;
    }
  }

  /// Triggers asynchronous Stockfish engine evaluation for single-player mode.
  Future<void> _triggerEngineMove(ChessMatch match) async {
    try {
      final difficulty = match.engineDifficulty ?? ChessConstants.engineMediumSkill;
      final engineResult = await _stockfishService.getBestMove(
        match.currentFen,
        skillLevel: difficulty,
        moveTimeMillis: ChessConstants.engineMoveTimeMillis,
      );

      if (engineResult != null) {
        await executeMove(
          engineResult.from,
          engineResult.to,
          promotion: engineResult.promotion,
        );
      }
    } catch (_) {}
  }

  /// Resigns the match for the active player.
  Future<void> resign() async {
    final currentMatch = state.value;
    if (currentMatch == null || !currentMatch.isActive) return;

    final currentUid = _authService.currentUid;
    final winnerUid =
        currentUid == currentMatch.whiteUid ? currentMatch.blackUid : currentMatch.whiteUid;

    await _firestoreService.resignMatch(
      matchId: currentMatch.matchId,
      resigningUid: currentUid,
    );

    state = AsyncData(
      currentMatch.copyWith(
        status: MatchStatus.resignation,
        winnerUid: winnerUid,
      ),
    );
  }

  /// Offers a draw.
  Future<void> offerDraw() async {
    final currentMatch = state.value;
    if (currentMatch == null || !currentMatch.isActive) return;

    final currentUid = _authService.currentUid;
    await _firestoreService.offerDraw(
      matchId: currentMatch.matchId,
      playerUid: currentUid,
    );

    state = AsyncData(
      currentMatch.copyWith(
        drawOfferedBy: currentUid,
      ),
    );
  }

  /// Responds to a pending draw offer.
  Future<void> respondToDraw(bool accept) async {
    final currentMatch = state.value;
    if (currentMatch == null || !currentMatch.isActive) return;

    await _firestoreService.respondToDrawOffer(
      matchId: currentMatch.matchId,
      accept: accept,
    );

    if (accept) {
      state = AsyncData(
        currentMatch.copyWith(
          status: MatchStatus.drawStalemate,
          drawOfferedBy: null,
        ),
      );
    } else {
      state = AsyncData(
        currentMatch.copyWith(
          drawOfferedBy: null,
        ),
      );
    }
  }

  /// Two-step timeout claim: requests server-side timeout calculation.
  Future<void> claimTimeoutWin(String timedOutColor) async {
    final currentMatch = state.value;
    if (currentMatch == null || !currentMatch.isActive) return;

    final newStatus =
        timedOutColor == 'w' ? MatchStatus.whiteTimeout : MatchStatus.blackTimeout;
    final winnerUid = timedOutColor == 'w' ? currentMatch.blackUid : currentMatch.whiteUid;

    await _firestoreService.claimTimeout(
      matchId: currentMatch.matchId,
      timedOutColor: timedOutColor,
    );

    state = AsyncData(
      currentMatch.copyWith(
        status: newStatus,
        winnerUid: winnerUid,
      ),
    );
  }

  /// Alias for claimTimeoutWin
  Future<void> claimTimeout(String timedOutColor) => claimTimeoutWin(timedOutColor);
}
