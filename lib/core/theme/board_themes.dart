import 'package:flutter/material.dart';

/// Design tokens for Enterprise Chess — Liquid Glass, Black & White edition.
///
/// Palette: strictly 9 greyscale hex steps, zero chroma.
/// All legacy saturated accents are preserved as board-square overlays only
/// (they must remain perceptible on the wooden board squares).
class BoardThemes {
  BoardThemes._();

  // ─── 9-Step Greyscale Palette ───────────────────────────────────────────────
  static const Color pitchBlack    = Color(0xFF000000);
  static const Color deepVoid      = Color(0xFF0A0A0A);
  static const Color darkCharcoal  = Color(0xFF1A1A1A);
  static const Color midSlate      = Color(0xFF333333);
  static const Color neutralGray   = Color(0xFF666666);
  static const Color mutedSilver   = Color(0xFF999999);
  static const Color offWhite      = Color(0xFFE0E0E0);
  static const Color brightSurface = Color(0xFFFAFAFA);
  static const Color pureWhite     = Color(0xFFFFFFFF);

  // ─── Backwards-compatible aliases (legacy chroma → greyscale) ──────────────
  // All saturated brand & accent colors from the previous palette are remapped
  // to their closest perceptual greyscale step so existing callers compile and
  // render monochromatic output without requiring mass file rewrites.
  /// @deprecated Replaced by [midSlate] (Liquid Glass greyscale).
  static const Color brandEmber   = midSlate;
  /// @deprecated Replaced by [neutralGray] (Liquid Glass greyscale).
  static const Color brandMagma   = neutralGray;
  /// @deprecated Replaced by [darkCharcoal] (Liquid Glass greyscale).
  static const Color brandFlame   = darkCharcoal;
  /// @deprecated Replaced by [mutedSilver] (Liquid Glass greyscale).
  static const Color brandGlow    = mutedSilver;
  /// @deprecated Replaced by [offWhite] (Liquid Glass greyscale).
  static const Color accentCyan   = offWhite;
  /// @deprecated Replaced by [brightSurface] (Liquid Glass greyscale).
  static const Color accentGold   = brightSurface;
  /// @deprecated Replaced by [mutedSilver] (Liquid Glass greyscale).
  static const Color accentEmerald = mutedSilver;
  /// @deprecated Replaced by [neutralGray] (Liquid Glass greyscale).
  static const Color accentRose   = neutralGray;
  /// @deprecated Replaced by [darkCharcoal] (Liquid Glass greyscale).
  static const Color dangerAlert  = darkCharcoal;


  // ─── Semantic surface aliases (greyscale only) ───────────────────────────────
  static const Color scaffoldBackground = deepVoid;
  static const Color surfaceDark        = darkCharcoal;
  static const Color surfaceCard        = midSlate;

  /// Liquid-glass wash: 8% white over dark content.
  static const Color surfaceGlass = Color(0x14FFFFFF);

  /// 1 px hairline at 12% opacity.
  static const Color borderHairline = Color(0x1FFFFFFF);
  static const Color borderSubtle   = Color(0xFF2D2D2D);

  // ─── Board Square Colors (Classic Tournament — unchanged) ────────────────────
  static const Color lightSquare = Color(0xFFE2E8F0);
  static const Color darkSquare  = Color(0xFF475569);

  // ─── Board Highlight Overlays (low-opacity, board use only) ─────────────────
  /// Selected square — cool blue tint kept for accessibility contrast.
  static const Color selectedSquareHighlight = Color(0x8838BDF8);
  static const Color legalMoveDot            = Color(0x9922C55E);
  static const Color captureRing             = Color(0xAAEF4444);
  static const Color checkSquareHighlight    = Color(0x99EF4444);
  static const Color lastMoveFromHighlight   = Color(0x66FBBF24);
  static const Color lastMoveToHighlight     = Color(0x88F59E0B);

  // ─── Typography (deprecated — use AppTypography instead) ────────────────────
  /// @deprecated Use [AppTypography.displayLarge] from app_typography.dart.
  static const TextStyle headerLarge = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: pureWhite,
  );

  /// @deprecated Use [AppTypography.titleMedium] from app_typography.dart.
  static const TextStyle headerMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: pureWhite,
  );

  /// @deprecated Use [AppTypography.bodyRegular] from app_typography.dart.
  static const TextStyle bodyRegular = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: mutedSilver,
  );

  /// @deprecated Use [AppTypography.clockDigits] from app_typography.dart.
  static const TextStyle clockDigits = TextStyle(
    fontFamily: 'Courier',
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
  );
}
