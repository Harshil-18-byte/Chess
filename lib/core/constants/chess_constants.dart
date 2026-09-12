/// Core constants for the Enterprise Chess application.
class ChessConstants {
  ChessConstants._();

  /// Standard Initial Position FEN.
  static const String initialFen =
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  /// Standard Elo calculation parameters.
  static const int defaultElo = 1200;
  static const int kFactor = 32;

  /// Time control presets in milliseconds.
  static const int bulletMillis = 60 * 1000; // 1 min
  static const int blitzMillis = 3 * 60 * 1000; // 3 min
  static const int rapidMillis = 10 * 60 * 1000; // 10 min
  static const int classicalMillis = 30 * 60 * 1000; // 30 min

  /// Critical clock threshold (visual alert triggers below 30s).
  static const int lowTimeWarningThresholdMillis = 30 * 1000;

  /// Default engine difficulty levels (1 to 20).
  static const int engineEasySkill = 3;
  static const int engineMediumSkill = 10;
  static const int engineHardSkill = 20;

  /// Engine time per move in milliseconds.
  static const int engineMoveTimeMillis = 800;

  /// Firestore Collection Names.
  static const String matchesCollection = 'matches';
  static const String movesSubcollection = 'moves';
  static const String usersCollection = 'users';
  static const String matchmakingQueueCollection = 'matchmaking_queue';
}
