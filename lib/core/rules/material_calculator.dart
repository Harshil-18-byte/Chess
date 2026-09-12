import 'dart:math' as math;

/// Represents calculated captured pieces and net material advantages from a chess board position.
class MaterialScore {
  /// Pieces captured by White (Black pieces taken: 'q', 'r', 'b', 'n', 'p').
  final List<String> whiteCapturedPieces;

  /// Pieces captured by Black (White pieces taken: 'Q', 'R', 'B', 'N', 'P').
  final List<String> blackCapturedPieces;

  /// Total surviving piece value for White.
  final int whiteValue;

  /// Total surviving piece value for Black.
  final int blackValue;

  /// Net material advantage for White (positive if White has more material).
  int get whiteAdvantage => whiteValue - blackValue;

  /// Net material advantage for Black (positive if Black has more material).
  int get blackAdvantage => blackValue - whiteValue;

  const MaterialScore({
    required this.whiteCapturedPieces,
    required this.blackCapturedPieces,
    required this.whiteValue,
    required this.blackValue,
  });

  /// Evaluates surviving pieces and captured collections from standard FEN position.
  factory MaterialScore.fromFen(String fen) {
    final placement = fen.split(' ').first;

    final counts = <String, int>{
      'P': 0, 'N': 0, 'B': 0, 'R': 0, 'Q': 0,
      'p': 0, 'n': 0, 'b': 0, 'r': 0, 'q': 0,
    };

    for (var i = 0; i < placement.length; i++) {
      final char = placement[i];
      if (counts.containsKey(char)) {
        counts[char] = (counts[char] ?? 0) + 1;
      }
    }

    final whiteVal = (counts['P']! * 1) +
        (counts['N']! * 3) +
        (counts['B']! * 3) +
        (counts['R']! * 5) +
        (counts['Q']! * 9);

    final blackVal = (counts['p']! * 1) +
        (counts['n']! * 3) +
        (counts['b']! * 3) +
        (counts['r']! * 5) +
        (counts['q']! * 9);

    // Captured by White (Black pieces missing from original 8p, 2r, 2n, 2b, 1q)
    final whiteCaptured = <String>[];
    _addCaptured(whiteCaptured, 'q', 1 - counts['q']!);
    _addCaptured(whiteCaptured, 'r', 2 - counts['r']!);
    _addCaptured(whiteCaptured, 'b', 2 - counts['b']!);
    _addCaptured(whiteCaptured, 'n', 2 - counts['n']!);
    _addCaptured(whiteCaptured, 'p', 8 - counts['p']!);

    // Captured by Black (White pieces missing from original 8P, 2R, 2N, 2B, 1Q)
    final blackCaptured = <String>[];
    _addCaptured(blackCaptured, 'Q', 1 - counts['Q']!);
    _addCaptured(blackCaptured, 'R', 2 - counts['R']!);
    _addCaptured(blackCaptured, 'B', 2 - counts['B']!);
    _addCaptured(blackCaptured, 'N', 2 - counts['N']!);
    _addCaptured(blackCaptured, 'P', 8 - counts['P']!);

    return MaterialScore(
      whiteCapturedPieces: whiteCaptured,
      blackCapturedPieces: blackCaptured,
      whiteValue: whiteVal,
      blackValue: blackVal,
    );
  }

  static void _addCaptured(List<String> list, String piece, int missing) {
    final count = math.max(0, missing);
    for (var i = 0; i < count; i++) {
      list.add(piece);
    }
  }

  /// Maps a piece symbol to its display unicode character.
  static String getPieceSymbol(String piece) {
    switch (piece) {
      case 'p': return '♟';
      case 'n': return '♞';
      case 'b': return '♝';
      case 'r': return '♜';
      case 'q': return '♛';
      case 'P': return '♙';
      case 'N': return '♘';
      case 'B': return '♗';
      case 'R': return '♖';
      case 'Q': return '♕';
      default: return '';
    }
  }
}
