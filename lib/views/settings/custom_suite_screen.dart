import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/board_themes.dart';
import '../../core/theme/app_typography.dart';
import '../../services/settings_service.dart';

class CustomSuiteScreen extends ConsumerStatefulWidget {
  const CustomSuiteScreen({super.key});

  @override
  ConsumerState<CustomSuiteScreen> createState() => _CustomSuiteScreenState();
}

class _CustomSuiteScreenState extends ConsumerState<CustomSuiteScreen> {
  final List<Map<String, dynamic>> _themes = [
    {
      'id': 'classic',
      'name': 'Classic Wood',
      'light': const Color(0xFFE2E8F0),
      'dark': const Color(0xFF475569),
    },
    {
      'id': 'neo',
      'name': 'Neo Synth',
      'light': const Color(0xFF2DD4BF),
      'dark': const Color(0xFF0F172A),
    },
    {
      'id': 'liquid',
      'name': 'Liquid Glass',
      'light': const Color(0xFF94A3B8),
      'dark': const Color(0xFF334155),
    },
    {
      'id': 'midnight',
      'name': 'Midnight Void',
      'light': const Color(0xFF4B5563),
      'dark': const Color(0xFF111827),
    },
  ];

  @override
  Widget build(BuildContext context) {
    final currentTheme = ref.watch(boardThemeModeProvider);

    return Scaffold(
      backgroundColor: BoardThemes.scaffoldBackground,
      appBar: AppBar(
        title: Text('CUSTOM SUITE', style: AppTypography.titleMedium),
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
          _buildSectionHeader('Board Theme'),
          const SizedBox(height: 8),
          ..._themes.map((theme) {
            final isSelected = theme['id'] == currentTheme;
            return GestureDetector(
              onTap: () {
                ref.read(boardThemeModeProvider.notifier).setTheme(theme['id']);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12.0),
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: BoardThemes.surfaceCard,
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(
                    color: isSelected ? BoardThemes.pureWhite : BoardThemes.borderSubtle,
                    width: isSelected ? 2.0 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: BoardThemes.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Container(color: theme['light'])),
                          Expanded(child: Container(color: theme['dark'])),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        theme['name'],
                        style: const TextStyle(
                          color: BoardThemes.pureWhite,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle, color: BoardThemes.pureWhite),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: BoardThemes.mutedSilver,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
