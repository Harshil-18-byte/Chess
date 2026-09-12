import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../core/constants/chess_constants.dart';
import '../core/errors/app_exceptions.dart';
import '../models/chess_match.dart';
import '../models/chess_move.dart';
import '../models/user_profile.dart';

/// Service managing Firestore database operations, atomic transactions, and anti-cheat constraints.
class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _matchesRef =>
      _firestore.collection(ChessConstants.matchesCollection);

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection(ChessConstants.usersCollection);

  CollectionReference<Map<String, dynamic>> get _queueRef =>
      _firestore.collection(ChessConstants.matchmakingQueueCollection);

  // ==========================================
  // USER PROFILES
  // ==========================================

  /// Retrieves a user profile by UID.
  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _usersRef.doc(uid).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return UserProfile.fromJson(doc.data()!);
  }

  /// Creates or updates a user profile.
  Future<void> saveUserProfile(UserProfile profile) async {
    await _usersRef.doc(profile.uid).set(
          profile.toJson(),
          SetOptions(merge: true),
        );
  }

  /// Updates Elo and win/loss/draw records after match conclusion.
  Future<void> updateUserStats({
    required String uid,
    required int eloDelta,
    required bool isWin,
    required bool isLoss,
    required bool isDraw,
  }) async {
    final docRef = _usersRef.doc(uid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      final profile = UserProfile.fromJson(snapshot.data()!);

      final updatedProfile = profile.copyWith(
        eloRating: (profile.eloRating + eloDelta).clamp(100, 3500),
        gamesPlayed: profile.gamesPlayed + 1,
        wins: isWin ? profile.wins + 1 : profile.wins,
        losses: isLoss ? profile.losses + 1 : profile.losses,
        draws: isDraw ? profile.draws + 1 : profile.draws,
        lastActiveAt: DateTime.now(),
      );

      transaction.update(docRef, updatedProfile.toJson());
    });
  }

  // ==========================================
  // MATCH MANAGEMENT & CREATION
  // ==========================================

  /// Creates a new match in Firestore.
  Future<ChessMatch> createMatch({
    required String whiteUid,
    required String blackUid,
    required String matchType, // 'human' or 'engine'
    int? timeControlMillis,
    int? engineDifficulty,
  }) async {
    // Check if player is banned
    final whiteProfile = await getUserProfile(whiteUid);
    if (whiteProfile != null && whiteProfile.isBanned) {
      throw const AuthRequiredException('Account is suspended from matchmaking.');
    }

    final matchId = const Uuid().v4();
    final timeControl = timeControlMillis ?? ChessConstants.rapidMillis;
    final now = DateTime.now();

    final match = ChessMatch(
      matchId: matchId,
      whiteUid: whiteUid,
      blackUid: blackUid,
      currentFen: ChessConstants.initialFen,
      status: MatchStatus.active,
      activeTurn: 'w',
      whiteMillisRemaining: timeControl,
      blackMillisRemaining: timeControl,
      lastMoveServerTimestamp: now,
      createdAt: now,
      matchType: matchType,
      engineDifficulty: engineDifficulty,
      moveCount: 0,
      positionHistory: [ChessConstants.initialFen],
      halfmoveClock: 0,
      processedClientMoveIds: [],
    );

    final matchMap = match.toJson();
    matchMap['lastMoveServerTimestamp'] = FieldValue.serverTimestamp();
    matchMap['createdAt'] = FieldValue.serverTimestamp();

    await _matchesRef.doc(matchId).set(matchMap);
    return match;
  }

  /// Reactive stream of a single match document.
  Stream<ChessMatch?> getMatchStream(String matchId) {
    return _matchesRef.doc(matchId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return ChessMatch.fromJson(snapshot.data()!);
    });
  }

  /// Reactive stream of moves for a match document.
  Stream<List<ChessMove>> getMovesStream(String matchId) {
    return _matchesRef
        .doc(matchId)
        .collection(ChessConstants.movesSubcollection)
        .orderBy('moveNumber', descending: false)
        .snapshots()
        .map((querySnapshot) {
      return querySnapshot.docs
          .map((doc) => ChessMove.fromJson(doc.data()))
          .toList();
    });
  }

  /// Retrieves completed match history for a user.
  Future<List<ChessMatch>> getUserMatchHistory(String uid) async {
    final whiteMatches = await _matchesRef
        .where('whiteUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(25)
        .get();

    final blackMatches = await _matchesRef
        .where('blackUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(25)
        .get();

    final allDocs = [...whiteMatches.docs, ...blackMatches.docs];
    allDocs.sort((a, b) {
      final aTime = (a.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
      final bTime = (b.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
      return bTime.compareTo(aTime);
    });

    return allDocs.map((doc) => ChessMatch.fromJson(doc.data())).toList();
  }

  // ==========================================
  // ATOMIC TRANSACTIONS WITH IDEMPOTENCY
  // ==========================================

  /// Submits an authoritative move inside a Firestore transaction with replay protection.
  Future<void> submitMoveTransaction({
    required String matchId,
    required String playerUid,
    required String newFen,
    required String san,
    required int moveNumber,
    required bool isCheck,
    required bool isCheckmate,
    required MatchStatus newStatus,
    required String clientMoveId,
    int? updatedHalfmoveClock,
    String? capturedPiece,
    String? promotionPiece,
  }) async {
    final matchDocRef = _matchesRef.doc(matchId);
    final movesColRef = matchDocRef.collection(ChessConstants.movesSubcollection);

    await _firestore.runTransaction((transaction) async {
      final matchSnapshot = await transaction.get(matchDocRef);
      if (!matchSnapshot.exists || matchSnapshot.data() == null) {
        throw StateError('Match document does not exist.');
      }

      final currentData = matchSnapshot.data()!;
      final currentMatch = ChessMatch.fromJson(currentData);

      if (currentMatch.status != MatchStatus.active) {
        throw StateError('Cannot submit move to an inactive match (${currentMatch.status.name}).');
      }

      // 1. Replay & Idempotency guard
      if (currentMatch.processedClientMoveIds.contains(clientMoveId)) {
        throw DuplicateMoveException('Move has already been applied.', clientMoveId: clientMoveId);
      }

      // 2. Verify turn and player identity
      final isWhite = currentMatch.whiteUid == playerUid;
      final isBlack = currentMatch.blackUid == playerUid;
      final isEngine = currentMatch.matchType == 'engine' && playerUid == 'engine_stockfish';

      if (!isWhite && !isBlack && !isEngine) {
        throw OutOfTurnException(
          'User is not a registered participant in this match.',
          expectedColor: currentMatch.activeTurn,
          attemptingUid: playerUid,
        );
      }

      if (currentMatch.activeTurn == 'w' && !isWhite && !isEngine) {
        throw OutOfTurnException(
          "It is White's turn, but caller is not White.",
          expectedColor: 'w',
          attemptingUid: playerUid,
        );
      }
      if (currentMatch.activeTurn == 'b' && !isBlack && !isEngine) {
        throw OutOfTurnException(
          "It is Black's turn, but caller is not Black.",
          expectedColor: 'b',
          attemptingUid: playerUid,
        );
      }

      // 3. Calculate authoritative elapsed time
      final lastTimestamp =
          (currentData['lastMoveServerTimestamp'] as Timestamp?)?.toDate() ??
              DateTime.now();
      final now = DateTime.now();
      final elapsedMillis = now.difference(lastTimestamp).inMilliseconds.clamp(0, 86400000);

      int updatedWhiteMillis = currentMatch.whiteMillisRemaining;
      int updatedBlackMillis = currentMatch.blackMillisRemaining;

      MatchStatus finalStatus = newStatus;

      if (currentMatch.activeTurn == 'w') {
        updatedWhiteMillis = (updatedWhiteMillis - elapsedMillis).clamp(0, 86400000);
        if (updatedWhiteMillis <= 0) {
          finalStatus = MatchStatus.whiteTimeout;
        }
      } else {
        updatedBlackMillis = (updatedBlackMillis - elapsedMillis).clamp(0, 86400000);
        if (updatedBlackMillis <= 0) {
          finalStatus = MatchStatus.blackTimeout;
        }
      }

      final nextTurn = currentMatch.activeTurn == 'w' ? 'b' : 'w';

      // Update position history for exact threefold repetition tracking
      final updatedHistory = List<String>.from(currentMatch.positionHistory)..add(newFen);
      final updatedProcessedIds = List<String>.from(currentMatch.processedClientMoveIds)..add(clientMoveId);

      // Update match document
      final updateData = <String, dynamic>{
        'currentFen': newFen,
        'activeTurn': nextTurn,
        'status': finalStatus.name,
        'whiteMillisRemaining': updatedWhiteMillis,
        'blackMillisRemaining': updatedBlackMillis,
        'lastMoveSan': san,
        'moveCount': currentMatch.moveCount + 1,
        'positionHistory': updatedHistory,
        'halfmoveClock': updatedHalfmoveClock ?? (currentMatch.halfmoveClock + 1),
        'processedClientMoveIds': updatedProcessedIds,
        'lastMoveServerTimestamp': FieldValue.serverTimestamp(),
        'drawOfferedBy': null,
      };

      if (finalStatus == MatchStatus.whiteWonCheckmate ||
          finalStatus == MatchStatus.blackTimeout) {
        updateData['winnerUid'] = currentMatch.whiteUid;
      } else if (finalStatus == MatchStatus.blackWonCheckmate ||
          finalStatus == MatchStatus.whiteTimeout) {
        updateData['winnerUid'] = currentMatch.blackUid;
      }

      transaction.update(matchDocRef, updateData);

      // Append immutable move record
      final moveDocRef = movesColRef.doc(moveNumber.toString().padLeft(4, '0'));
      final move = ChessMove(
        moveNumber: moveNumber,
        san: san,
        fenAfterMove: newFen,
        serverTimestamp: now,
        movedBy: playerUid,
        capturedPiece: capturedPiece,
        isCheck: isCheck,
        isCheckmate: isCheckmate,
        promotionPiece: promotionPiece,
        clientMoveId: clientMoveId,
      );

      final moveMap = move.toJson();
      moveMap['serverTimestamp'] = FieldValue.serverTimestamp();
      transaction.set(moveDocRef, moveMap);
    });
  }

  /// Resigns an active match for the given player.
  Future<void> resignMatch({
    required String matchId,
    required String resigningUid,
  }) async {
    final matchDocRef = _matchesRef.doc(matchId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(matchDocRef);
      if (!snapshot.exists || snapshot.data() == null) return;
      final match = ChessMatch.fromJson(snapshot.data()!);
      if (match.status != MatchStatus.active) return;

      final winnerUid = resigningUid == match.whiteUid ? match.blackUid : match.whiteUid;

      transaction.update(matchDocRef, {
        'status': MatchStatus.resignation.name,
        'winnerUid': winnerUid,
        'lastMoveServerTimestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Offers a draw.
  Future<void> offerDraw({
    required String matchId,
    required String playerUid,
  }) async {
    await _matchesRef.doc(matchId).update({
      'drawOfferedBy': playerUid,
    });
  }

  /// Responds to a draw offer.
  Future<void> respondToDrawOffer({
    required String matchId,
    required bool accept,
  }) async {
    if (accept) {
      await _matchesRef.doc(matchId).update({
        'status': MatchStatus.drawStalemate.name,
        'drawOfferedBy': null,
        'lastMoveServerTimestamp': FieldValue.serverTimestamp(),
      });
    } else {
      await _matchesRef.doc(matchId).update({
        'drawOfferedBy': null,
      });
    }
  }

  /// Claims timeout if server clock expired.
  Future<void> claimTimeout({
    required String matchId,
    required String timedOutColor,
  }) async {
    final matchDocRef = _matchesRef.doc(matchId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(matchDocRef);
      if (!snapshot.exists || snapshot.data() == null) return;
      final match = ChessMatch.fromJson(snapshot.data()!);
      if (match.status != MatchStatus.active) return;

      final newStatus =
          timedOutColor == 'w' ? MatchStatus.whiteTimeout : MatchStatus.blackTimeout;
      final winnerUid = timedOutColor == 'w' ? match.blackUid : match.whiteUid;

      transaction.update(matchDocRef, {
        'status': newStatus.name,
        'winnerUid': winnerUid,
        'lastMoveServerTimestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  // ==========================================
  // MATCHMAKING QUEUE
  // ==========================================

  /// Enqueues the user and searches for a waiting opponent.
  Future<String?> findOrCreateMatchmakingMatch({
    required String uid,
    required int timeControlMillis,
  }) async {
    final profile = await getUserProfile(uid);
    if (profile != null && profile.isBanned) {
      throw const AuthRequiredException('Account is banned from matchmaking.');
    }

    final query = await _queueRef
        .where('timeControlMillis', isEqualTo: timeControlMillis)
        .where('uid', isNotEqualTo: uid)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final opponentDoc = query.docs.first;
      final opponentUid = opponentDoc.data()['uid'] as String;

      await _queueRef.doc(opponentDoc.id).delete();

      final match = await createMatch(
        whiteUid: opponentUid,
        blackUid: uid,
        matchType: 'human',
        timeControlMillis: timeControlMillis,
      );

      return match.matchId;
    } else {
      await _queueRef.doc(uid).set({
        'uid': uid,
        'timeControlMillis': timeControlMillis,
        'queuedAt': FieldValue.serverTimestamp(),
      });
      return null;
    }
  }

  /// Removes the user from matchmaking queue.
  Future<void> leaveMatchmakingQueue(String uid) async {
    await _queueRef.doc(uid).delete();
  }
}
