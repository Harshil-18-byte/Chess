import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/board_themes.dart';

/// A reusable glassmorphism container mimicking iOS glass UI.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double blur;
  final double opacity;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 12.0,
    this.padding = const EdgeInsets.all(16.0),
    this.margin = EdgeInsets.zero,
    this.blur = 15.0,
    this.opacity = 0.08, // Subtle opacity for dark mode
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: BoardThemes.pureWhite.withValues(alpha: opacity),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: BoardThemes.pureWhite.withValues(alpha: 0.15),
                width: 1.0,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
