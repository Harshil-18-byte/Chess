import 'package:flutter/material.dart';
import '../../../core/theme/board_themes.dart';
import '../../../core/theme/app_typography.dart';

class CapturedPiecesTray extends StatelessWidget {
  final String fen;
  final bool isWhitePlayer; // true if this tray is for the white player's captures

  const CapturedPiecesTray({
    super.key,
    required this.fen,
    required this.isWhitePlayer,
  });

  Map<String, int> _getMaterial(String fenStr) {
    final board = fenStr.split(' ')[0];
    final counts = <String, int>{
      'P': 0, 'N': 0, 'B': 0, 'R': 0, 'Q': 0,
      'p': 0, 'n': 0, 'b': 0, 'r': 0, 'q': 0,
    };
    for (int i = 0; i < board.length; i++) {
      final char = board[i];
      if (counts.containsKey(char)) {
        counts[char] = counts[char]! + 1;
      }
    }
    return counts;
  }

  int _getMaterialValue(Map<String, int> counts, bool isWhite) {
    final p = isWhite ? counts['P']! : counts['p']!;
    final n = isWhite ? counts['N']! : counts['n']!;
    final b = isWhite ? counts['B']! : counts['b']!;
    final r = isWhite ? counts['R']! : counts['r']!;
    final q = isWhite ? counts['Q']! : counts['q']!;
    return (p * 1) + (n * 3) + (b * 3) + (r * 5) + (q * 9);
  }

  @override
  Widget build(BuildContext context) {
    final currentCounts = _getMaterial(fen);
    
    // Starting counts
    const startCounts = {
      'P': 8, 'N': 2, 'B': 2, 'R': 2, 'Q': 1,
      'p': 8, 'n': 2, 'b': 2, 'r': 2, 'q': 1,
    };

    final capturedWhite = <String>[];
    final capturedBlack = <String>[];

    // White pieces captured by Black
    for (final p in ['Q', 'R', 'B', 'N', 'P']) {
      final diff = startCounts[p]! - currentCounts[p]!;
      for (int i = 0; i < diff; i++) {
        capturedWhite.add(p);
      }
    }

    // Black pieces captured by White
    for (final p in ['q', 'r', 'b', 'n', 'p']) {
      final diff = startCounts[p]! - currentCounts[p]!;
      for (int i = 0; i < diff; i++) {
        capturedBlack.add(p);
      }
    }

    final whiteValue = _getMaterialValue(currentCounts, true);
    final blackValue = _getMaterialValue(currentCounts, false);

    final isWhiteAdvantage = whiteValue > blackValue;
    final isBlackAdvantage = blackValue > whiteValue;
    final diff = (whiteValue - blackValue).abs();

    final myCaptures = isWhitePlayer ? capturedBlack : capturedWhite;
    final myAdvantage = isWhitePlayer ? isWhiteAdvantage : isBlackAdvantage;
    
    // We map chars to symbols
    const symbols = {
      'p': '♟', 'n': '♞', 'b': '♝', 'r': '♜', 'q': '♛',
      'P': '♙', 'N': '♘', 'B': '♗', 'R': '♖', 'Q': '♕',
    };

    return Row(
      children: [
        ...myCaptures.map((p) => Padding(
          padding: const EdgeInsets.only(right: 2.0),
          child: Text(
            symbols[p] ?? '',
            style: TextStyle(
              fontSize: 16,
              color: isWhitePlayer ? BoardThemes.pureWhite.withAlpha(150) : BoardThemes.pitchBlack.withAlpha(150),
            ),
          ),
        )),
        if (myCaptures.isNotEmpty && myAdvantage && diff > 0) ...[
          const SizedBox(width: 8),
          Text(
            '+$diff',
            style: AppTypography.labelSmall.copyWith(
              color: BoardThemes.mutedSilver,
              fontWeight: FontWeight.bold,
            ),
          ),
        ]
      ],
    );
  }
}
