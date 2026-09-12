import 'package:flutter/material.dart';
import '../core/theme/board_themes.dart';

/// Represents standardized chess skill grades from Beginner to Grandmaster.
enum ChessGrade {
  beginner,
  novice,
  intermediate,
  advanced,
  master,
  grandmaster;

  /// User-facing display title for the grade.
  String get title {
    switch (this) {
      case ChessGrade.beginner:
        return 'Beginner';
      case ChessGrade.novice:
        return 'Novice';
      case ChessGrade.intermediate:
        return 'Intermediate';
      case ChessGrade.advanced:
        return 'Advanced';
      case ChessGrade.master:
        return 'Master';
      case ChessGrade.grandmaster:
        return 'Grandmaster';
    }
  }

  /// Detailed descriptive subtitle explaining the skill tier.
  String get description {
    switch (this) {
      case ChessGrade.beginner:
        return 'Learning rules & fundamental piece movements';
      case ChessGrade.novice:
        return 'Basic tactical awareness, captures & simple mates';
      case ChessGrade.intermediate:
        return 'Solid positional play, forks, pins & piece coordination';
      case ChessGrade.advanced:
        return 'Sharp tactical calculation, opening theory & endgames';
      case ChessGrade.master:
        return 'Deep strategic planning, pawn structures & master play';
      case ChessGrade.grandmaster:
        return 'World-class calculation, opening mastery & precise play';
    }
  }

  /// Benchmark Elo rating associated with this skill tier.
  int get elo {
    switch (this) {
      case ChessGrade.beginner:
        return 600;
      case ChessGrade.novice:
        return 1000;
      case ChessGrade.intermediate:
        return 1400;
      case ChessGrade.advanced:
        return 1800;
      case ChessGrade.master:
        return 2200;
      case ChessGrade.grandmaster:
        return 2600;
    }
  }

  /// Corresponding Stockfish UCI skill level (0 to 20).
  int get stockfishSkill {
    switch (this) {
      case ChessGrade.beginner:
        return 2;
      case ChessGrade.novice:
        return 5;
      case ChessGrade.intermediate:
        return 9;
      case ChessGrade.advanced:
        return 13;
      case ChessGrade.master:
        return 17;
      case ChessGrade.grandmaster:
        return 20;
    }
  }

  /// Allocated evaluation time per move in milliseconds for engine play.
  int get engineMoveTimeMillis {
    switch (this) {
      case ChessGrade.beginner:
        return 300;
      case ChessGrade.novice:
        return 450;
      case ChessGrade.intermediate:
        return 700;
      case ChessGrade.advanced:
        return 1000;
      case ChessGrade.master:
        return 1500;
      case ChessGrade.grandmaster:
        return 2000;
    }
  }

  /// Representative chess piece symbol used in UI badges.
  String get iconSymbol {
    switch (this) {
      case ChessGrade.beginner:
        return '♟';
      case ChessGrade.novice:
        return '♞';
      case ChessGrade.intermediate:
        return '♝';
      case ChessGrade.advanced:
        return '♜';
      case ChessGrade.master:
        return '♛';
      case ChessGrade.grandmaster:
        return '♚';
    }
  }

  /// UI theme accent color corresponding to the grade hierarchy.
  Color get color {
    switch (this) {
      case ChessGrade.beginner:
        return BoardThemes.accentEmerald;
      case ChessGrade.novice:
        return BoardThemes.accentCyan;
      case ChessGrade.intermediate:
        return BoardThemes.accentGold;
      case ChessGrade.advanced:
        return BoardThemes.accentRose;
      case ChessGrade.master:
        return BoardThemes.brandEmber;
      case ChessGrade.grandmaster:
        return BoardThemes.brandGlow;
    }
  }

  /// Resolves a [ChessGrade] dynamically from a numeric Elo rating.
  static ChessGrade fromElo(int elo) {
    if (elo < 800) {
      return ChessGrade.beginner;
    } else if (elo < 1200) {
      return ChessGrade.novice;
    } else if (elo < 1600) {
      return ChessGrade.intermediate;
    } else if (elo < 2000) {
      return ChessGrade.advanced;
    } else if (elo < 2400) {
      return ChessGrade.master;
    } else {
      return ChessGrade.grandmaster;
    }
  }
}
