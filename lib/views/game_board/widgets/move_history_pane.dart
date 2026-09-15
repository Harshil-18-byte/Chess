import 'package:flutter/material.dart';
import '../../../core/theme/board_themes.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/chess_move.dart';

class MoveHistoryPane extends StatelessWidget {
  final List<ChessMove> moves;

  const MoveHistoryPane({super.key, required this.moves});

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = [];
    
    for (int i = 0; i < moves.length; i += 2) {
      final moveNumber = (i ~/ 2) + 1;
      final whiteMove = moves[i].san;
      final blackMove = (i + 1 < moves.length) ? moves[i + 1].san : '';

      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Text(
                  '$moveNumber.',
                  style: TextStyle(color: BoardThemes.mutedSilver, fontSize: 14),
                ),
              ),
              Expanded(
                child: Text(
                  whiteMove,
                  style: TextStyle(color: BoardThemes.pureWhite, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: Text(
                  blackMove,
                  style: TextStyle(color: BoardThemes.pureWhite, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: BoardThemes.surfaceDark,
        border: Border(left: BorderSide(color: BoardThemes.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: BoardThemes.scaffoldBackground,
            child: Text('MATCH HISTORY', style: AppTypography.labelSmall),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: rows,
            ),
          ),
        ],
      ),
    );
  }
}

