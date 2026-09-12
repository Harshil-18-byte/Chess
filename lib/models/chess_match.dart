import 'package:cloud_firestore/cloud_firestore.dart';

/// Exhaustive MatchStatus enum matching architectural specification.
enum MatchStatus {
  active,
  whiteWonCheckmate,
  blackWonCheckmate,
  drawStalemate,
  drawThreefoldRepetition,
  drawFiftyMoveRule,
  drawInsufficientMaterial,
  whiteTimeout,
  blackTimeout,
  resignation,
  abandoned,
}

/// Board rendering mode (2D classic vs 3D perspective).
enum BoardRenderMode {
  twoD,
  threeD,
}

/// Represents the active state of a chess match with anti-cheat, draw history, and idempotency tracking.
class ChessMatch {
  final String matchId;
  final String whiteUid;
  final String blackUid;
  final String currentFen;
  final MatchStatus status;
  final String activeTurn; // 'w' or 'b'
  final int whiteMillisRemaining;
  final int blackMillisRemaining;
  final DateTime lastMoveServerTimestamp;
  final DateTime createdAt;
  final String matchType; // 'human' or 'engine'
  final int? engineDifficulty;
  final int moveCount;
  final List<String> positionHistory; // Full FEN position history for exact threefold repetition
  final int halfmoveClock; // 50-move rule counter
  final List<String> processedClientMoveIds; // Set of UUIDs for replay / double-submit guard
  final String? drawOfferedBy;
  final String? lastMoveSan;
  final String? winnerUid;
  final String renderMode; // '2d' or '3d' (per-user viewport configuration)

  const ChessMatch({
    required this.matchId,
    required this.whiteUid,
    required this.blackUid,
    required this.currentFen,
    required this.status,
    required this.activeTurn,
    required this.whiteMillisRemaining,
    required this.blackMillisRemaining,
    required this.lastMoveServerTimestamp,
    required this.createdAt,
    required this.matchType,
    this.engineDifficulty,
    this.moveCount = 0,
    this.positionHistory = const [],
    this.halfmoveClock = 0,
    this.processedClientMoveIds = const [],
    this.drawOfferedBy,
    this.lastMoveSan,
    this.winnerUid,
    this.renderMode = '2d',
  });

  /// True if the game is in an active playable state.
  bool get isActive => status == MatchStatus.active;

  /// True if white's turn.
  bool get isWhiteTurn => activeTurn == 'w';

  /// Helper to convert string to [MatchStatus] safely.
  static MatchStatus parseStatus(String? value) {
    if (value == null) return MatchStatus.active;
    for (final status in MatchStatus.values) {
      if (status.name == value) {
        return status;
      }
    }
    return MatchStatus.active;
  }

  /// Deserializes a Firestore or JSON map into [ChessMatch].
  factory ChessMatch.fromJson(Map<String, dynamic> json) {
    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      } else if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return DateTime.now();
    }

    List<String> parseStringList(dynamic list) {
      if (list is List) {
        return list.map((e) => e.toString()).toList();
      }
      return [];
    }

    return ChessMatch(
      matchId: json['matchId'] as String? ?? '',
      whiteUid: json['whiteUid'] as String? ?? '',
      blackUid: json['blackUid'] as String? ?? '',
      currentFen: json['currentFen'] as String? ?? '',
      status: parseStatus(json['status'] as String?),
      activeTurn: json['activeTurn'] as String? ?? 'w',
      whiteMillisRemaining: (json['whiteMillisRemaining'] as num?)?.toInt() ?? 600000,
      blackMillisRemaining: (json['blackMillisRemaining'] as num?)?.toInt() ?? 600000,
      lastMoveServerTimestamp: parseDateTime(json['lastMoveServerTimestamp']),
      createdAt: parseDateTime(json['createdAt']),
      matchType: json['matchType'] as String? ?? 'human',
      engineDifficulty: (json['engineDifficulty'] as num?)?.toInt(),
      moveCount: (json['moveCount'] as num?)?.toInt() ?? 0,
      positionHistory: parseStringList(json['positionHistory']),
      halfmoveClock: (json['halfmoveClock'] as num?)?.toInt() ?? 0,
      processedClientMoveIds: parseStringList(json['processedClientMoveIds']),
      drawOfferedBy: json['drawOfferedBy'] as String?,
      lastMoveSan: json['lastMoveSan'] as String?,
      winnerUid: json['winnerUid'] as String?,
      renderMode: json['renderMode'] as String? ?? '2d',
    );
  }

  /// Serializes [ChessMatch] to a map for Firestore writes.
  Map<String, dynamic> toJson() {
    return {
      'matchId': matchId,
      'whiteUid': whiteUid,
      'blackUid': blackUid,
      'currentFen': currentFen,
      'status': status.name,
      'activeTurn': activeTurn,
      'whiteMillisRemaining': whiteMillisRemaining,
      'blackMillisRemaining': blackMillisRemaining,
      'lastMoveServerTimestamp': Timestamp.fromDate(lastMoveServerTimestamp),
      'createdAt': Timestamp.fromDate(createdAt),
      'matchType': matchType,
      'engineDifficulty': engineDifficulty,
      'moveCount': moveCount,
      'positionHistory': positionHistory,
      'halfmoveClock': halfmoveClock,
      'processedClientMoveIds': processedClientMoveIds,
      'drawOfferedBy': drawOfferedBy,
      'lastMoveSan': lastMoveSan,
      'winnerUid': winnerUid,
      'renderMode': renderMode,
    };
  }

  /// Returns a copy of [ChessMatch] with updated fields.
  ChessMatch copyWith({
    String? matchId,
    String? whiteUid,
    String? blackUid,
    String? currentFen,
    MatchStatus? status,
    String? activeTurn,
    int? whiteMillisRemaining,
    int? blackMillisRemaining,
    DateTime? lastMoveServerTimestamp,
    DateTime? createdAt,
    String? matchType,
    int? engineDifficulty,
    int? moveCount,
    List<String>? positionHistory,
    int? halfmoveClock,
    List<String>? processedClientMoveIds,
    String? drawOfferedBy,
    String? lastMoveSan,
    String? winnerUid,
    String? renderMode,
  }) {
    return ChessMatch(
      matchId: matchId ?? this.matchId,
      whiteUid: whiteUid ?? this.whiteUid,
      blackUid: blackUid ?? this.blackUid,
      currentFen: currentFen ?? this.currentFen,
      status: status ?? this.status,
      activeTurn: activeTurn ?? this.activeTurn,
      whiteMillisRemaining: whiteMillisRemaining ?? this.whiteMillisRemaining,
      blackMillisRemaining: blackMillisRemaining ?? this.blackMillisRemaining,
      lastMoveServerTimestamp:
          lastMoveServerTimestamp ?? this.lastMoveServerTimestamp,
      createdAt: createdAt ?? this.createdAt,
      matchType: matchType ?? this.matchType,
      engineDifficulty: engineDifficulty ?? this.engineDifficulty,
      moveCount: moveCount ?? this.moveCount,
      positionHistory: positionHistory ?? this.positionHistory,
      halfmoveClock: halfmoveClock ?? this.halfmoveClock,
      processedClientMoveIds:
          processedClientMoveIds ?? this.processedClientMoveIds,
      drawOfferedBy: drawOfferedBy ?? this.drawOfferedBy,
      lastMoveSan: lastMoveSan ?? this.lastMoveSan,
      winnerUid: winnerUid ?? this.winnerUid,
      renderMode: renderMode ?? this.renderMode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChessMatch &&
          runtimeType == other.runtimeType &&
          matchId == other.matchId &&
          whiteUid == other.whiteUid &&
          blackUid == other.blackUid &&
          currentFen == other.currentFen &&
          status == other.status &&
          activeTurn == other.activeTurn &&
          whiteMillisRemaining == other.whiteMillisRemaining &&
          blackMillisRemaining == other.blackMillisRemaining &&
          matchType == other.matchType &&
          moveCount == other.moveCount &&
          halfmoveClock == other.halfmoveClock &&
          engineDifficulty == other.engineDifficulty &&
          drawOfferedBy == other.drawOfferedBy &&
          renderMode == other.renderMode;

  @override
  int get hashCode =>
      matchId.hashCode ^
      whiteUid.hashCode ^
      blackUid.hashCode ^
      currentFen.hashCode ^
      status.hashCode ^
      activeTurn.hashCode ^
      whiteMillisRemaining.hashCode ^
      blackMillisRemaining.hashCode ^
      matchType.hashCode ^
      moveCount.hashCode ^
      halfmoveClock.hashCode ^
      (engineDifficulty?.hashCode ?? 0) ^
      (drawOfferedBy?.hashCode ?? 0) ^
      renderMode.hashCode;
}
