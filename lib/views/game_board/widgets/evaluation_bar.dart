import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/board_themes.dart';

/// A sleek vertical evaluation bar displaying real-time advantage from engine analysis.
class EvaluationBar extends StatelessWidget {
  /// Evaluation in centipawns (+100 = White +1 pawn, -250 = Black +2.5 pawns).
  final double? centipawns;

  /// Forced mate in N moves (positive = White mates in N, negative = Black mates in N).
  final int? mateInMoves;

  /// Whether White is at the bottom (standard perspective).
  final bool isWhiteOrientation;

  /// Height of the board / bar.
  final double height;

  const EvaluationBar({
    super.key,
    this.centipawns,
    this.mateInMoves,
    this.isWhiteOrientation = true,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    double whiteAdvantageRatio = 0.5; // Default 50% even position

    String evalText = '0.0';

    if (mateInMoves != null) {
      if (mateInMoves! > 0) {
        whiteAdvantageRatio = 1.0;
        evalText = '#${mateInMoves!}';
      } else {
        whiteAdvantageRatio = 0.0;
        evalText = '#${mateInMoves!.abs()}';
      }
    } else if (centipawns != null) {
      // Standard Lichess / Chess.com winning chance sigmoid formula
      // P = 2 / (1 + exp(-0.00368208 * cp)) - 1, mapped from [0..1]
      final cp = centipawns!;
      final sigmoid = 1.0 / (1.0 + math.exp(-0.004 * cp));
      whiteAdvantageRatio = sigmoid.clamp(0.05, 0.95);

      final pawns = cp / 100.0;
      evalText = (pawns >= 0 ? '+' : '') + pawns.toStringAsFixed(1);
    }

    // Adjust for orientation
    final whiteHeightFactor = isWhiteOrientation
        ? whiteAdvantageRatio
        : (1.0 - whiteAdvantageRatio);

    return Container(
      width: 22,
      height: height,
      decoration: BoxDecoration(
        color: BoardThemes.surfaceDark,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: BoardThemes.borderSubtle, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Black advantage background (top or bottom based on orientation)
          Container(color: const Color(0xFF262522)),

          // White advantage fill
          Align(
            alignment: isWhiteOrientation ? Alignment.bottomCenter : Alignment.topCenter,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: whiteHeightFactor),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              builder: (context, factor, child) {
                return FractionallySizedBox(
                  heightFactor: factor,
                  widthFactor: 1.0,
                  child: Container(
                    color: const Color(0xFFF0D9B5), // Light square palette color
                  ),
                );
              },
            ),
          ),

          // Evaluation text label
          Positioned(
            bottom: isWhiteOrientation && whiteAdvantageRatio > 0.5 ? 6 : null,
            top: !isWhiteOrientation || whiteAdvantageRatio <= 0.5 ? 6 : null,
            child: RotatedBox(
              quarterTurns: 3,
              child: Text(
                evalText,
                style: TextStyle(
                  color: (isWhiteOrientation && whiteAdvantageRatio > 0.5)
                      ? Colors.black87
                      : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
