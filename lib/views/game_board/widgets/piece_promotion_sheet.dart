import 'package:flutter/material.dart';
import '../../../core/theme/board_themes.dart';
import '../../../core/theme/app_typography.dart';

class PiecePromotionSheet extends StatelessWidget {
  final bool isWhite;

  const PiecePromotionSheet({super.key, required this.isWhite});

  static Future<String?> show(BuildContext context, {required bool isWhite}) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PiecePromotionSheet(isWhite: isWhite),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pieces = [
      {'val': 'q', 'icon': isWhite ? '♕' : '♛', 'label': 'Queen'},
      {'val': 'r', 'icon': isWhite ? '♖' : '♜', 'label': 'Rook'},
      {'val': 'b', 'icon': isWhite ? '♗' : '♝', 'label': 'Bishop'},
      {'val': 'n', 'icon': isWhite ? '♘' : '♞', 'label': 'Knight'},
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: BoardThemes.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: BoardThemes.borderSubtle)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('PROMOTE PAWN', style: AppTypography.titleMedium),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: pieces.map((p) {
                return GestureDetector(
                  onTap: () => Navigator.of(context).pop(p['val']),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: BoardThemes.scaffoldBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: BoardThemes.borderSubtle),
                        ),
                        child: Text(
                          p['icon']!,
                          style: TextStyle(
                            fontSize: 32,
                            color: isWhite ? BoardThemes.pureWhite : BoardThemes.pitchBlack,
                            shadows: const [Shadow(color: Colors.white24, blurRadius: 4)],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(p['label']!, style: AppTypography.labelSmall),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
