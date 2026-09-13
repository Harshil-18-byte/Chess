import 'package:flutter/material.dart';

/// Renders a crisp vector/styled chess piece with drag capabilities.
class ChessPieceWidget extends StatelessWidget {
  final String pieceChar; // e.g. 'P', 'p', 'N', 'n', 'B', 'b', 'R', 'r', 'Q', 'q', 'K', 'k'
  final double size;
  final bool isDraggable;
  final bool isGhost;
  final Function(DragUpdateDetails)? onDragUpdate;
  final VoidCallback? onDragEnd;

  const ChessPieceWidget({
    super.key,
    required this.pieceChar,
    this.size = 44,
    this.isDraggable = false,
    this.isGhost = false,
    this.onDragUpdate,
    this.onDragEnd,
  });

  /// True if piece is White.
  bool get isWhite => pieceChar == pieceChar.toUpperCase();

  /// Gets stylized Unicode chess symbol.
  String get pieceSymbol {
    switch (pieceChar.toUpperCase()) {
      case 'K':
        return '♚';
      case 'Q':
        return '♛';
      case 'R':
        return '♜';
      case 'B':
        return '♝';
      case 'N':
        return '♞';
      case 'P':
        return '♟';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final symbol = pieceSymbol;
    if (symbol.isEmpty) return const SizedBox.shrink();

    Widget pieceWidget = Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Subtle drop shadow / outline
          Text(
            symbol,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: size,
              height: 1.0,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = isWhite ? 2.5 : 2.0
                ..color = isWhite ? const Color(0xFF1E293B) : Colors.black,
            ),
          ),
          // Fill
          Text(
            symbol,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: size,
              height: 1.0,
              fontWeight: FontWeight.bold,
              color: isWhite ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B),
              shadows: isWhite
                  ? [
                      const Shadow(
                        blurRadius: 4,
                        color: Color(0x66FFFFFF),
                        offset: Offset(0, 1),
                      )
                    ]
                  : [
                      const Shadow(
                        blurRadius: 6,
                        color: Color(0x88000000),
                        offset: Offset(0, 2),
                      )
                    ],
            ),
          ),
        ],
      ),
    );

    if (isGhost) {
      pieceWidget = Opacity(
        opacity: 0.5,
        child: pieceWidget,
      );
    }

    if (!isDraggable) {
      return pieceWidget;
    }

    return Draggable<String>(
      data: pieceChar,
      onDragUpdate: onDragUpdate,
      onDragEnd: (details) {
        onDragEnd?.call();
      },
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(
          scale: 1.2,
          child: pieceWidget,
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: pieceWidget,
      ),
      child: pieceWidget,
    );
  }
}
