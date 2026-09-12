import 'package:flutter/material.dart';

/// Design tokens and board theme configurations for Enterprise Chess.
class BoardThemes {
  BoardThemes._();

  // Chessical Flagship Theme - Magma Obsidian & Ember Glow
  static const Color scaffoldBackground = Color(0xFF0C0F17);
  static const Color surfaceDark = Color(0xFF141923);
  static const Color surfaceCard = Color(0xFF1C2230);
  static const Color surfaceGlass = Color(0xCC182030);
  static const Color borderSubtle = Color(0xFF2D3748);

  // Chessical Signature Brand Accents (Fractured Obsidian & Magma Core)
  static const Color brandEmber = Color(0xFFFF6B00);
  static const Color brandMagma = Color(0xFFFF8A00);
  static const Color brandFlame = Color(0xFFFF4500);
  static const Color brandGlow = Color(0xFFFFB03B);

  // Accent & Status Colors
  static const Color accentCyan = Color(0xFF38BDF8);
  static const Color accentGold = Color(0xFFFBBF24);
  static const Color accentEmerald = Color(0xFF34D399);
  static const Color accentRose = Color(0xFFF43F5E);
  static const Color dangerAlert = Color(0xFFEF4444);

  // Board Square Colors - Classic Tournament
  static const Color lightSquare = Color(0xFFE2E8F0);
  static const Color darkSquare = Color(0xFF475569);

  // Highlight & Interaction Overlays
  static const Color selectedSquareHighlight = Color(0x8838BDF8);
  static const Color legalMoveDot = Color(0x9922C55E);
  static const Color captureRing = Color(0xAAEF4444);
  static const Color checkSquareHighlight = Color(0x99EF4444);
  static const Color lastMoveFromHighlight = Color(0x66FBBF24);
  static const Color lastMoveToHighlight = Color(0x88F59E0B);

  // Typography Styles
  static const TextStyle headerLarge = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: Colors.white,
  );

  static const TextStyle headerMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: Colors.white,
  );

  static const TextStyle bodyRegular = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: Color(0xFF94A3B8),
  );

  static const TextStyle clockDigits = TextStyle(
    fontFamily: 'Courier',
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
  );
}
