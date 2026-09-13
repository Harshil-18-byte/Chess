import 'package:flutter/material.dart';
import '../core/theme/board_themes.dart';
import '../core/theme/app_typography.dart';

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BoardThemes.scaffoldBackground,
      appBar: AppBar(
        title: Text('CREDITS', style: AppTypography.titleMedium),
        backgroundColor: BoardThemes.surfaceDark,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Center(
            child: Text(
              'BACK',
              style: TextStyle(
                color: BoardThemes.pureWhite,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildCreditSection('3D Assets', [
            'Chess Pieces - Licensed under CC-BY 4.0',
            'Board Model - OpenGameArt.org',
          ]),
          _buildCreditSection('Audio', [
            'Move Sounds - Custom synthesized',
            'Capture Sounds - Zapsplat (CC0)',
          ]),
          _buildCreditSection('Engine', [
            'Stockfish 16.1 - GPLv3',
          ]),
        ],
      ),
    );
  }

  Widget _buildCreditSection(String title, List<String> credits) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: BoardThemes.mutedSilver,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          ...credits.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  c,
                  style: const TextStyle(
                    color: BoardThemes.pureWhite,
                    fontSize: 14,
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
