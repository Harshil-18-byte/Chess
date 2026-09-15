import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/board_themes.dart';
import '../../../services/settings_service.dart';
import 'chess_piece.dart';

/// Single square on the chess board with explicit 0-63 linear math and drag-and-drop targets.
class BoardSquareWidget extends ConsumerWidget {
  final int linearIndex; // 0 (a8) to 63 (h1)
  final bool isFlipped; // True if viewing from Black's perspective
  final String? pieceChar; // Piece on this square or null
  final bool isSelected;
  final bool isLegalTarget;
  final bool isCaptureTarget;
  final bool isKingInCheck;
  final bool isLastMoveFrom;
  final bool isLastMoveTo;
  final bool canDragPiece;
  final VoidCallback onTap;
  final Function(String fromSquare) onPieceDropped;
  final Function(String fromSquare, DragUpdateDetails details)? onDragUpdate;
  final Function(String fromSquare)? onDragEnd;

  const BoardSquareWidget({
    super.key,
    required this.linearIndex,
    required this.isFlipped,
    this.pieceChar,
    this.isSelected = false,
    this.isLegalTarget = false,
    this.isCaptureTarget = false,
    this.isKingInCheck = false,
    this.isLastMoveFrom = false,
    this.isLastMoveTo = false,
    this.canDragPiece = false,
    required this.onTap,
    required this.onPieceDropped,
    this.onDragUpdate,
    this.onDragEnd,
  });

  /// Explicit mathematical conversion: 0-63 linear index -> algebraic square (e.g. 'e4')
  static String indexToSquare(int index) {
    assert(index >= 0 && index <= 63, 'Index must be between 0 and 63');
    final rank = 7 - (index ~/ 8); // rank index 0..7 (corresponds to rank 1..8)
    final file = index % 8; // file index 0..7 (corresponds to a..h)
    final fileChar = String.fromCharCode('a'.codeUnitAt(0) + file);
    final rankChar = '${rank + 1}';
    return '$fileChar$rankChar';
  }

  /// Explicit mathematical conversion: algebraic square -> 0-63 linear index
  static int squareToIndex(String square) {
    assert(square.length == 2, 'Square must be 2 characters (e.g. e4)');
    final file = square.toLowerCase().codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.parse(square[1]) - 1;
    return (7 - rank) * 8 + file;
  }

  /// Calculates effective index depending on board orientation
  int get effectiveIndex => isFlipped ? (63 - linearIndex) : linearIndex;

  /// Square name in algebraic notation
  String get algebraicSquare => indexToSquare(effectiveIndex);

  /// True if square is light
  bool get isLightSquare {
    final rank = 7 - (effectiveIndex ~/ 8);
    final file = effectiveIndex % 8;
    return (rank + file) % 2 != 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeId = ref.watch(boardThemeModeProvider);
    final themeColors = BoardThemes.getThemeColors(themeId);
    
    final squareColor =
        isLightSquare ? themeColors.$1 : themeColors.$2;

    // Check rank/file edge for coordinate labels
    final file = effectiveIndex % 8;
    final rank = 7 - (effectiveIndex ~/ 8);
    final showFileLabel = isFlipped ? rank == 7 : rank == 0;
    final showRankLabel = isFlipped ? file == 7 : file == 0;

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        // Details contains source piece or metadata; we trigger callback with source square
        onPieceDropped(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            decoration: BoxDecoration(
              color: squareColor,
            ),
            child: Stack(
              children: [
                // Base background overlay highlights
                if (isLastMoveFrom)
                  Container(color: BoardThemes.lastMoveFromHighlight),
                if (isLastMoveTo)
                  Container(color: BoardThemes.lastMoveToHighlight),
                if (isSelected)
                  Container(color: BoardThemes.selectedSquareHighlight),
                if (isKingInCheck)
                  Container(
                    decoration: BoxDecoration(
                      color: BoardThemes.checkSquareHighlight,
                      border: Border.all(color: BoardThemes.dangerAlert, width: 2),
                    ),
                  ),
                if (candidateData.isNotEmpty)
                  Container(
                    color: const Color(0x6638BDF8),
                  ),

                // Coordinate rank label (e.g. '8', '7'...)
                if (showRankLabel)
                  Positioned(
                    top: 2,
                    left: 2,
                    child: Text(
                      '${rank + 1}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isLightSquare
                            ? themeColors.$2.withAlpha(200)
                            : themeColors.$1.withAlpha(200),
                      ),
                    ),
                  ),

                // Coordinate file label (e.g. 'a', 'b'...)
                if (showFileLabel)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Text(
                      String.fromCharCode('a'.codeUnitAt(0) + file),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isLightSquare
                            ? themeColors.$2.withAlpha(200)
                            : themeColors.$1.withAlpha(200),
                      ),
                    ),
                  ),

                // Piece Widget
                if (pieceChar != null)
                  Center(
                    child: ChessPieceWidget(
                      pieceChar: pieceChar!,
                      isDraggable: canDragPiece,
                      onDragUpdate: onDragUpdate != null
                          ? (details) => onDragUpdate!(algebraicSquare, details)
                          : null,
                      onDragEnd: onDragEnd != null
                          ? () => onDragEnd!(algebraicSquare)
                          : null,
                    ),
                  ),

                // Legal Move Indicators
                if (isLegalTarget && !isCaptureTarget)
                  Center(
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: BoardThemes.legalMoveDot,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),

                // Capture Target Indicator (Ring around piece)
                if (isCaptureTarget)
                  Positioned.fill(
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: BoardThemes.captureRing,
                          width: 3.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
