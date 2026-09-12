import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single immutable move in a match history with cryptographic idempotency tracking.
class ChessMove {
  final int moveNumber;
  final String san;
  final String fenAfterMove;
  final DateTime serverTimestamp;
  final String movedBy;
  final String? capturedPiece;
  final bool isCheck;
  final bool isCheckmate;
  final String? promotionPiece;
  final String clientMoveId; // UUID generated client-side for idempotency / replay defense

  const ChessMove({
    required this.moveNumber,
    required this.san,
    required this.fenAfterMove,
    required this.serverTimestamp,
    required this.movedBy,
    this.capturedPiece,
    required this.isCheck,
    required this.isCheckmate,
    this.promotionPiece,
    required this.clientMoveId,
  });

  /// Factory constructor to deserialize Firestore / JSON map.
  factory ChessMove.fromJson(Map<String, dynamic> json) {
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

    return ChessMove(
      moveNumber: (json['moveNumber'] as num?)?.toInt() ?? 1,
      san: json['san'] as String? ?? '',
      fenAfterMove: json['fenAfterMove'] as String? ?? '',
      serverTimestamp: parseDateTime(json['serverTimestamp']),
      movedBy: json['movedBy'] as String? ?? '',
      capturedPiece: json['capturedPiece'] as String?,
      isCheck: json['isCheck'] as bool? ?? false,
      isCheckmate: json['isCheckmate'] as bool? ?? false,
      promotionPiece: json['promotionPiece'] as String?,
      clientMoveId: json['clientMoveId'] as String? ?? '',
    );
  }

  /// Converts the [ChessMove] instance to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'moveNumber': moveNumber,
      'san': san,
      'fenAfterMove': fenAfterMove,
      'serverTimestamp': Timestamp.fromDate(serverTimestamp),
      'movedBy': movedBy,
      'capturedPiece': capturedPiece,
      'isCheck': isCheck,
      'isCheckmate': isCheckmate,
      'promotionPiece': promotionPiece,
      'clientMoveId': clientMoveId,
    };
  }

  /// Returns a copy of [ChessMove] with updated fields.
  ChessMove copyWith({
    int? moveNumber,
    String? san,
    String? fenAfterMove,
    DateTime? serverTimestamp,
    String? movedBy,
    String? capturedPiece,
    bool? isCheck,
    bool? isCheckmate,
    String? promotionPiece,
    String? clientMoveId,
  }) {
    return ChessMove(
      moveNumber: moveNumber ?? this.moveNumber,
      san: san ?? this.san,
      fenAfterMove: fenAfterMove ?? this.fenAfterMove,
      serverTimestamp: serverTimestamp ?? this.serverTimestamp,
      movedBy: movedBy ?? this.movedBy,
      capturedPiece: capturedPiece ?? this.capturedPiece,
      isCheck: isCheck ?? this.isCheck,
      isCheckmate: isCheckmate ?? this.isCheckmate,
      promotionPiece: promotionPiece ?? this.promotionPiece,
      clientMoveId: clientMoveId ?? this.clientMoveId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChessMove &&
          runtimeType == other.runtimeType &&
          moveNumber == other.moveNumber &&
          san == other.san &&
          fenAfterMove == other.fenAfterMove &&
          movedBy == other.movedBy &&
          capturedPiece == other.capturedPiece &&
          isCheck == other.isCheck &&
          isCheckmate == other.isCheckmate &&
          promotionPiece == other.promotionPiece &&
          clientMoveId == other.clientMoveId;

  @override
  int get hashCode =>
      moveNumber.hashCode ^
      san.hashCode ^
      fenAfterMove.hashCode ^
      movedBy.hashCode ^
      (capturedPiece?.hashCode ?? 0) ^
      isCheck.hashCode ^
      isCheckmate.hashCode ^
      (promotionPiece?.hashCode ?? 0) ^
      clientMoveId.hashCode;
}
