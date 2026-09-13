import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/board_themes.dart';
import '../../core/theme/liquid_glass.dart';
import '../../services/settings_service.dart';

class LoadingOverlay extends ConsumerWidget {
  final String message;

  const LoadingOverlay({super.key, this.message = 'LOADING'});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduceMotion = ref.watch(reduceMotionProvider);

    Widget content = Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: BoardThemes.pureWhite),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(
                  color: BoardThemes.pureWhite,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
    );

    return Positioned.fill(
      child: reduceMotion
          ? Container(color: BoardThemes.surfaceDark.withAlpha(200), child: content)
          : LiquidGlassContainer(borderRadius: BorderRadius.zero, child: content),
    );
  }
}
