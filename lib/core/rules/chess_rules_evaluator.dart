import 'package:chess/chess.dart' as chess_lib;

/// Authoritative rules evaluator for draw conditions: threefold repetition, 50-move rule, and insufficient material.
class ChessRulesEvaluator {
  ChessRulesEvaluator._();

  /// Evaluates if the current FEN position has occurred 3 or more times in history.
  /// Standard rules require exact match of piece placement, active turn, castling rights, and en passant target.
  static bool isThreefoldRepetition(String currentFen, List<String> positionHistory) {
    String normalizeFenForRepetition(String fen) {
      final parts = fen.trim().split(' ');
      if (parts.length >= 4) {
        // board, turn, castling, en passant
        return '${parts[0]} ${parts[1]} ${parts[2]} ${parts[3]}';
      }
      return fen;
    }

    final normalizedCurrent = normalizeFenForRepetition(currentFen);
    int occurrences = 0;

    for (final pastFen in positionHistory) {
      if (normalizeFenForRepetition(pastFen) == normalizedCurrent) {
        occurrences++;
      }
    }

    return occurrences >= 3;
  }

  /// Exhaustively evaluates insufficient material:
  /// 1. King vs King
  /// 2. King + Bishop vs King
  /// 3. King + Knight vs King
  /// 4. King + Bishop vs King + Bishop (where both bishops are on same-color squares)
  static bool isInsufficientMaterial(chess_lib.Chess chess) {
    final pieces = <String, List<String>>{}; // 'w': ['k', 'b'], 'b': ['k', 'b']
    final bishopSquares = <String, List<String>>{'w': [], 'b': []};

    String pieceTypeChar(chess_lib.PieceType pt) {
      if (pt == chess_lib.PieceType.PAWN) return 'p';
      if (pt == chess_lib.PieceType.KNIGHT) return 'n';
      if (pt == chess_lib.PieceType.BISHOP) return 'b';
      if (pt == chess_lib.PieceType.ROOK) return 'r';
      if (pt == chess_lib.PieceType.QUEEN) return 'q';
      if (pt == chess_lib.PieceType.KING) return 'k';
      return pt.name.toLowerCase().substring(0, 1);
    }

    for (int rank = 1; rank <= 8; rank++) {
      for (int file = 0; file < 8; file++) {
        final fileChar = String.fromCharCode('a'.codeUnitAt(0) + file);
        final sq = '$fileChar$rank';
        final piece = chess.get(sq);
        if (piece != null) {
          final color = piece.color == chess_lib.Color.WHITE ? 'w' : 'b';
          final type = pieceTypeChar(piece.type);
          pieces.putIfAbsent(color, () => []).add(type);

          if (type == 'b') {
            bishopSquares[color]!.add(sq);
          }
        }
      }
    }

    final whitePieces = pieces['w'] ?? [];
    final blackPieces = pieces['b'] ?? [];

    // If any pawns, rooks, or queens are present, material is sufficient
    final heavyOrPawns = ['p', 'r', 'q'];
    if (whitePieces.any(heavyOrPawns.contains) || blackPieces.any(heavyOrPawns.contains)) {
      return false;
    }

    // Case 1: King vs King (K vs K)
    if (whitePieces.length == 1 && blackPieces.length == 1) {
      return true;
    }

    // Case 2: King + Minor vs King (K+B vs K or K+N vs K)
    if (whitePieces.length == 2 && blackPieces.length == 1) {
      if (whitePieces.contains('b') || whitePieces.contains('n')) return true;
    }
    if (blackPieces.length == 2 && whitePieces.length == 1) {
      if (blackPieces.contains('b') || blackPieces.contains('n')) return true;
    }

    // Case 4: King + Bishop vs King + Bishop (K+B vs K+B)
    if (whitePieces.length == 2 &&
        blackPieces.length == 2 &&
        whitePieces.contains('b') &&
        blackPieces.contains('b')) {
      final whiteBishopSq = bishopSquares['w']!.first;
      final blackBishopSq = bishopSquares['b']!.first;

      bool isSquareLight(String sq) {
        final fileIdx = sq.codeUnitAt(0) - 'a'.codeUnitAt(0);
        final rankIdx = int.parse(sq[1]) - 1;
        return (rankIdx + fileIdx) % 2 != 0;
      }

      // If both bishops are on the same square color, checkmate is mathematically impossible
      if (isSquareLight(whiteBishopSq) == isSquareLight(blackBishopSq)) {
        return true;
      }
    }

    return false;
  }
}
