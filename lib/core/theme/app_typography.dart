import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'board_themes.dart';

/// Enterprise Chess — Typographic system.
///
/// Display family : Cinzel (classical serif — titles, headings, outcomes).
/// UI / body family: Inter (humanist sans — clocks, SAN notation, buttons, dialogs).
///
/// Scale is defined as an explicit ratio-based ladder:
///   display → 48 / 40 / 32
///   title   → 24 / 20
///   label   → 16 / 14 / 12
///   body    → 16 / 14 / 12
///   mono    → 22 / 18 / 14  (clock digits, SAN notation)
///
/// All text is rendered without forced all-caps transforms.
/// Colour defaults: [BoardThemes.pureWhite] on dark surfaces.
class AppTypography {
  AppTypography._();

  // ─── Display / Hero ──────────────────────────────────────────────────────────

  /// 48 px — App name, match outcome announcement ("Checkmate", "Draw").
  static TextStyle get displayHero => GoogleFonts.cinzel(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.0,
        color: BoardThemes.pureWhite,
      );

  /// 40 px — Section hero text, player name in pre-game lobby.
  static TextStyle get displayLarge => GoogleFonts.cinzel(
        fontSize: 40,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: BoardThemes.pureWhite,
      );

  /// 32 px — Card headings, modal titles.
  static TextStyle get displayMedium => GoogleFonts.cinzel(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: BoardThemes.pureWhite,
      );

  // ─── Title / Heading ─────────────────────────────────────────────────────────

  /// 24 px — Section headings, player display name.
  static TextStyle get titleLarge => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: BoardThemes.pureWhite,
      );

  /// 20 px — Card titles, dialog headings.
  static TextStyle get titleMedium => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: BoardThemes.pureWhite,
      );

  // ─── Label / UI Controls ─────────────────────────────────────────────────────

  /// 16 px — Primary button labels, chip text, navigation items.
  static TextStyle get labelLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: BoardThemes.pureWhite,
      );

  /// 14 px — Secondary labels, badge text, tab labels.
  static TextStyle get labelMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: BoardThemes.offWhite,
      );

  /// 12 px — Captions, metadata, timestamp, grade sub-labels.
  static TextStyle get labelSmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
        color: BoardThemes.mutedSilver,
      );

  // ─── Body Text ───────────────────────────────────────────────────────────────

  /// 16 px — Dialog body, chat messages, description paragraphs.
  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.0,
        color: BoardThemes.offWhite,
      );

  /// 14 px — Secondary body, move list entries, PGN notation.
  static TextStyle get bodyRegular => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.0,
        color: BoardThemes.mutedSilver,
      );

  /// 12 px — Fine print, legal text, accessibility disclaimers.
  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w300,
        letterSpacing: 0.1,
        color: BoardThemes.neutralGray,
      );

  // ─── Monospace / Game-Critical ───────────────────────────────────────────────

  /// 22 px — Clock digits (hh:mm:ss, mm:ss). Uses tabular figures.
  static TextStyle get clockLarge => GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: BoardThemes.pureWhite,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// 18 px — Compact clock in analysis panel / move-list header.
  static TextStyle get clockMedium => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: BoardThemes.offWhite,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// 14 px — SAN move notation in PGN export preview, move list rows.
  static TextStyle get sanNotation => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: BoardThemes.offWhite,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// 12 px — Evaluation score labels (+1.5, #3, =).
  static TextStyle get evalScore => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: BoardThemes.pureWhite,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  /// Returns [base] with [color] applied — shorthand for on-surface overrides.
  static TextStyle withColor(TextStyle base, Color color) =>
      base.copyWith(color: color);

  /// Returns [base] at reduced opacity for disabled/inactive states.
  static TextStyle dimmed(TextStyle base, {double opacity = 0.4}) =>
      base.copyWith(color: (base.color ?? BoardThemes.pureWhite).withValues(alpha: opacity));
}
