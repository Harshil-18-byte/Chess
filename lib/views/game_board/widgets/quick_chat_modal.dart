import 'package:flutter/material.dart';
import '../../../core/theme/board_themes.dart';

/// Modal dialog for selecting quick messages and emoji reactions during a game.
class QuickChatModal extends StatelessWidget {
  final Function(String message, bool isEmote) onSelected;

  const QuickChatModal({
    super.key,
    required this.onSelected,
  });

  static const List<String> emotes = [
    '🤝', '👏', '🎯', '👑', '🔥', '☕', '⚡', '🛡️', '⏳', '💡', '😎', '🎉'
  ];

  static const List<String> phrases = [
    'Good luck, have fun! 🍀',
    'Nice move! 🎯',
    'Well played! 👏',
    'Thanks for the game! 🤝',
    'Thinking... ⏳',
    'Oops! 😅',
    'Rematch? ⚔️',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: BoardThemes.surfaceDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: BoardThemes.borderSubtle),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Quick Reactions',
                  style: BoardThemes.headerMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Emotes Grid
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: emotes.map((emote) {
                return InkWell(
                  onTap: () {
                    onSelected(emote, true);
                    Navigator.of(context).pop();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: BoardThemes.scaffoldBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: BoardThemes.borderSubtle),
                    ),
                    child: Text(emote, style: const TextStyle(fontSize: 24)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            const Text(
              'Preset Messages',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            // Preset Messages List
            ...phrases.map((phrase) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: () {
                    onSelected(phrase, false);
                    Navigator.of(context).pop();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: BoardThemes.scaffoldBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: BoardThemes.borderSubtle.withAlpha(50)),
                    ),
                    child: Text(
                      phrase,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
