/// Core typed exceptions hierarchy for Enterprise Chess.
abstract class ChessAppException implements Exception {
  final String message;
  const ChessAppException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when a move violates the rules of chess (e.g. pinned piece, invalid path).
class IllegalMoveException extends ChessAppException {
  final String from;
  final String to;
  final String? fen;

  const IllegalMoveException(
    super.message, {
    required this.from,
    required this.to,
    this.fen,
  });

  @override
  String toString() => 'IllegalMoveException: $message (from: $from, to: $to)';
}

/// Thrown when a client attempts to submit a move when it is not their turn.
class OutOfTurnException extends ChessAppException {
  final String expectedColor;
  final String attemptingUid;

  const OutOfTurnException(
    super.message, {
    required this.expectedColor,
    required this.attemptingUid,
  });
}

/// Thrown when a move attempt is based on a stale board state / out-of-sync FEN.
class StaleStateException extends ChessAppException {
  final String clientFen;
  final String serverFen;

  const StaleStateException(
    super.message, {
    required this.clientFen,
    required this.serverFen,
  });
}

/// Thrown when a duplicate clientMoveId is submitted (replay / network retry duplicate).
class DuplicateMoveException extends ChessAppException {
  final String clientMoveId;

  const DuplicateMoveException(
    super.message, {
    required this.clientMoveId,
  });
}

/// Thrown when a client exceeds write/move frequency limits.
class RateLimitExceededException extends ChessAppException {
  final int retryAfterMillis;

  const RateLimitExceededException(
    super.message, {
    this.retryAfterMillis = 1000,
  });
}

/// Thrown when an unauthenticated or guest user attempts an action requiring verified auth.
class AuthRequiredException extends ChessAppException {
  const AuthRequiredException(super.message);
}

/// Thrown when the 3D scene engine fails to initialize graphics context or load assets.
class RenderInitException extends ChessAppException {
  final Object? cause;

  const RenderInitException(
    super.message, {
    this.cause,
  });
}
