import 'package:cloud_firestore/cloud_firestore.dart';
import 'chess_grade.dart';

/// Represents a persistent user profile with historical statistics, rating, and anti-cheat status.
class UserProfile {
  final String uid;
  final String displayName;
  final int eloRating;
  final int gamesPlayed;
  final int wins;
  final int losses;
  final int draws;
  final DateTime createdAt;
  final DateTime lastActiveAt;
  final bool isBanned;

  /// Current chess skill grade derived from Elo rating.
  ChessGrade get chessGrade => ChessGrade.fromElo(eloRating);

  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.eloRating,
    required this.gamesPlayed,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.createdAt,
    required this.lastActiveAt,
    this.isBanned = false,
  });

  /// Creates a [UserProfile] from a JSON / Firestore map.
  factory UserProfile.fromJson(Map<String, dynamic> json) {
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

    return UserProfile(
      uid: json['uid'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Anonymous Player',
      eloRating: (json['eloRating'] as num?)?.toInt() ?? 1200,
      gamesPlayed: (json['gamesPlayed'] as num?)?.toInt() ?? 0,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      draws: (json['draws'] as num?)?.toInt() ?? 0,
      createdAt: parseDateTime(json['createdAt']),
      lastActiveAt: parseDateTime(json['lastActiveAt']),
      isBanned: json['isBanned'] as bool? ?? false,
    );
  }

  /// Converts the [UserProfile] to a serializable map.
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'displayName': displayName,
      'eloRating': eloRating,
      'chessGrade': chessGrade.name,
      'gamesPlayed': gamesPlayed,
      'wins': wins,
      'losses': losses,
      'draws': draws,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActiveAt': Timestamp.fromDate(lastActiveAt),
      'isBanned': isBanned,
    };
  }

  /// Returns a copy of [UserProfile] with updated fields.
  UserProfile copyWith({
    String? uid,
    String? displayName,
    int? eloRating,
    int? gamesPlayed,
    int? wins,
    int? losses,
    int? draws,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    bool? isBanned,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      eloRating: eloRating ?? this.eloRating,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      draws: draws ?? this.draws,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      isBanned: isBanned ?? this.isBanned,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          displayName == other.displayName &&
          eloRating == other.eloRating &&
          gamesPlayed == other.gamesPlayed &&
          wins == other.wins &&
          losses == other.losses &&
          draws == other.draws &&
          isBanned == other.isBanned;

  @override
  int get hashCode =>
      uid.hashCode ^
      displayName.hashCode ^
      eloRating.hashCode ^
      gamesPlayed.hashCode ^
      wins.hashCode ^
      losses.hashCode ^
      draws.hashCode ^
      isBanned.hashCode;
}
