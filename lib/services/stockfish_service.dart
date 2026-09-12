import 'dart:async';
import 'package:stockfish/stockfish.dart';

/// Represents a parsed move output from the UCI engine.
class EngineMoveResult {
  final String from;
  final String to;
  final String? promotion;
  final String rawUci;

  const EngineMoveResult({
    required this.from,
    required this.to,
    this.promotion,
    required this.rawUci,
  });

  @override
  String toString() => 'EngineMoveResult($rawUci, from: $from, to: $to, promo: $promotion)';
}

/// Service managing the single on-device Stockfish FFI isolate.
class StockfishService {
  static StockfishService? _instance;
  Stockfish? _stockfish;
  StreamSubscription<String>? _stdoutSubscription;
  Completer<EngineMoveResult?>? _pendingMoveCompleter;
  bool _isReady = false;

  StockfishService._();

  /// Singleton accessor to enforce single-instance lifecycle constraint.
  static StockfishService get instance {
    _instance ??= StockfishService._();
    return _instance!;
  }

  /// Initializes the Stockfish engine and UCI protocol.
  Future<void> initialize() async {
    if (_stockfish != null && _isReady) return;

    try {
      _stockfish = Stockfish();
      _stdoutSubscription = _stockfish!.stdout.listen(_handleStdout);

      // Initialize UCI communication
      _stockfish!.stdin = 'uci\n';
      _stockfish!.stdin = 'isready\n';
      _isReady = true;
    } catch (e) {
      _isReady = false;
      dispose();
      rethrow;
    }
  }

  /// Handles incoming output lines from Stockfish stdout stream.
  void _handleStdout(String line) {
    final trimmed = line.trim();
    if (trimmed.startsWith('bestmove')) {
      final parts = trimmed.split(' ');
      if (parts.length >= 2) {
        final uciMove = parts[1];
        if (uciMove != '(none)' && uciMove.length >= 4) {
          final from = uciMove.substring(0, 2);
          final to = uciMove.substring(2, 4);
          final promotion = uciMove.length > 4 ? uciMove.substring(4, 5) : null;

          _pendingMoveCompleter?.complete(
            EngineMoveResult(
              from: from,
              to: to,
              promotion: promotion,
              rawUci: uciMove,
            ),
          );
        } else {
          _pendingMoveCompleter?.complete(null);
        }
      } else {
        _pendingMoveCompleter?.complete(null);
      }
      _pendingMoveCompleter = null;
    }
  }

  /// Computes the best move for a given FEN string and difficulty level.
  Future<EngineMoveResult?> getBestMove(
    String fen, {
    int skillLevel = 10,
    int moveTimeMillis = 800,
  }) async {
    await initialize();

    // Cancel any previous pending evaluation
    if (_pendingMoveCompleter != null && !_pendingMoveCompleter!.isCompleted) {
      _pendingMoveCompleter!.complete(null);
    }

    _pendingMoveCompleter = Completer<EngineMoveResult?>();

    final clampedSkill = skillLevel.clamp(0, 20);
    _stockfish!.stdin = 'setoption name Skill Level value $clampedSkill\n';
    _stockfish!.stdin = 'ucinewgame\n';
    _stockfish!.stdin = 'position fen $fen\n';
    _stockfish!.stdin = 'go movetime $moveTimeMillis\n';

    // Timeout safety fallback (2x movetime + 2000ms buffer)
    final timeoutFuture = Future.delayed(
      Duration(milliseconds: moveTimeMillis * 2 + 2000),
      () => null,
    );

    return Future.any([
      _pendingMoveCompleter!.future,
      timeoutFuture,
    ]);
  }

  /// Disposes of the Stockfish instance and native isolate cleanly.
  void dispose() {
    if (_pendingMoveCompleter != null && !_pendingMoveCompleter!.isCompleted) {
      _pendingMoveCompleter!.complete(null);
      _pendingMoveCompleter = null;
    }

    _stdoutSubscription?.cancel();
    _stdoutSubscription = null;

    try {
      _stockfish?.dispose();
    } catch (_) {}

    _stockfish = null;
    _isReady = false;
  }
}
