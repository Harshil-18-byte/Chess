import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../core/constants/chess_constants.dart';
import '../core/errors/app_exceptions.dart';
import '../models/chess_match.dart';
import '../models/chess_move.dart';
import '../models/user_profile.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Service managing Firestore database operations, atomic transactions, and anti-cheat constraints.
class FirestoreService {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  FirestoreService({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

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
    required bool isTimedMatch,
  }) async {
    final docRef = _usersRef.doc(uid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      final profile = UserProfile.fromJson(snapshot.data()!);

      final updatedProfile = profile.copyWith(
        eloRating: isTimedMatch ? (profile.eloRating + eloDelta).clamp(100, 3500) : profile.eloRating,
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
    bool isTimedMatch = true,
    String? timeControlPreset,
    int? initialMinutes,
    int? incrementSeconds,
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
      isTimedMatch: isTimedMatch,
      whiteMillisRemaining: isTimedMatch ? timeControl : null,
      blackMillisRemaining: isTimedMatch ? timeControl : null,
      lastMoveServerTimestamp: now,
      createdAt: now,
      timeControlPreset: timeControlPreset,
      initialMinutes: initialMinutes,
      incrementSeconds: incrementSeconds,
      matchType: matchType,
      engineDifficulty: engineDifficulty,
      moveCount: 0,
      positionHistory: [ChessConstants.initialFen],
      halfmoveClock: 0,
      processedClientMoveIds: [],
    );

    final matchMap = match.toJson();
    if (isTimedMatch) {
      matchMap['lastMoveServerTimestamp'] = FieldValue.serverTimestamp();
    }
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
    required String fromSquare,
    required String toSquare,
    int? updatedHalfmoveClock,
    String? capturedPiece,
    String? promotionPiece,
    bool useLocalFallback = false, // True for emulator mock tests
  }) async {
    if (!useLocalFallback) {
      final callable = _functions.httpsCallable('validateMove');
      await callable.call({
        'matchId': matchId,
        'from': fromSquare,
        'to': toSquare,
        'promotion': promotionPiece,
        'clientMoveId': clientMoveId,
      });
      return;
    }

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

      // 3. Calculate authoritative elapsed time ONLY if timed
      MatchStatus finalStatus = newStatus;
      int? updatedWhiteMillis = currentMatch.whiteMillisRemaining;
      int? updatedBlackMillis = currentMatch.blackMillisRemaining;

      if (currentMatch.isTimedMatch) {
        final now = DateTime.now();
        final lastTimestamp =
            (currentData['lastMoveServerTimestamp'] as Timestamp?)?.toDate() ??
                now;
        final elapsedMillis = now.difference(lastTimestamp).inMilliseconds.clamp(0, 86400000);
        
        final incrementMillis = (currentMatch.incrementSeconds ?? 0) * 1000;

        if (currentMatch.activeTurn == 'w') {
          updatedWhiteMillis = ((updatedWhiteMillis ?? 0) - elapsedMillis + incrementMillis).clamp(0, 86400000);
          if (updatedWhiteMillis <= 0) {
            finalStatus = MatchStatus.whiteTimeout;
          }
        } else {
          updatedBlackMillis = ((updatedBlackMillis ?? 0) - elapsedMillis + incrementMillis).clamp(0, 86400000);
          if (updatedBlackMillis <= 0) {
            finalStatus = MatchStatus.blackTimeout;
          }
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
        'lastMoveSan': san,
        'moveCount': currentMatch.moveCount + 1,
        'positionHistory': updatedHistory,
        'halfmoveClock': updatedHalfmoveClock ?? (currentMatch.halfmoveClock + 1),
        'processedClientMoveIds': updatedProcessedIds,
        'drawOfferedBy': null,
      };

      if (currentMatch.isTimedMatch) {
        updateData['whiteMillisRemaining'] = updatedWhiteMillis;
        updateData['blackMillisRemaining'] = updatedBlackMillis;
      }
      
      updateData['lastMoveServerTimestamp'] = FieldValue.serverTimestamp();

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
        serverTimestamp: DateTime.now(),
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
      if (!match.isTimedMatch) throw StateError('NotATimedMatchException');
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

  /// Claims abandonment for an untimed match if the opponent has been inactive for > 24 hours.
  Future<void> claimAbandonment({
    required String matchId,
    required String claimantUid,
  }) async {
    final matchDocRef = _matchesRef.doc(matchId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(matchDocRef);
      if (!snapshot.exists || snapshot.data() == null) return;
      
      final currentData = snapshot.data()!;
      final match = ChessMatch.fromJson(currentData);
      
      if (match.status != MatchStatus.active) return;
      if (match.isTimedMatch) return; // Only for untimed matches
      
      // Verify caller is a participant and it's NOT their turn
      final isWhite = match.whiteUid == claimantUid;
      final isBlack = match.blackUid == claimantUid;
      if (!isWhite && !isBlack) return;
      
      if (match.activeTurn == 'w' && isWhite) return; // It's white's turn, white can't claim abandonment
      if (match.activeTurn == 'b' && isBlack) return; // It's black's turn, black can't claim abandonment
      
      final lastTimestamp = (currentData['lastMoveServerTimestamp'] as Timestamp?)?.toDate();
      if (lastTimestamp == null) return;
      
      final now = DateTime.now();
      if (now.difference(lastTimestamp).inHours >= 24) {
        transaction.update(matchDocRef, {
          'status': MatchStatus.abandoned.name,
          'winnerUid': claimantUid,
          'lastMoveServerTimestamp': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // ==========================================
  // MATCHMAKING QUEUE
  // ==========================================

  /// Enqueues the user and searches for a waiting opponent.
  Future<String?> findOrCreateMatchmakingMatch({
    required String uid,
    required bool isTimedMatch,
    String? timeControlPreset,
    int? initialMinutes,
    int? incrementSeconds,
    int? timeControlMillis,
  }) async {
    final profile = await getUserProfile(uid);
    if (profile != null && profile.isBanned) {
      throw const AuthRequiredException('Account is banned from matchmaking.');
    }

    var queueQuery = _queueRef
        .where('isTimedMatch', isEqualTo: isTimedMatch)
        .where('uid', isNotEqualTo: uid);
        
    if (isTimedMatch) {
      queueQuery = queueQuery
          .where('timeControlPreset', isEqualTo: timeControlPreset)
          .where('initialMinutes', isEqualTo: initialMinutes)
          .where('incrementSeconds', isEqualTo: incrementSeconds);
    }
        
    final query = await queueQuery.limit(1).get();

    if (query.docs.isNotEmpty) {
      final opponentDoc = query.docs.first;
      final opponentUid = opponentDoc.data()['uid'] as String;

      await _queueRef.doc(opponentDoc.id).delete();

      final match = await createMatch(
        whiteUid: opponentUid,
        blackUid: uid,
        matchType: 'human',
        isTimedMatch: isTimedMatch,
        timeControlPreset: timeControlPreset,
        initialMinutes: initialMinutes,
        incrementSeconds: incrementSeconds,
        timeControlMillis: timeControlMillis,
      );

      return match.matchId;
    } else {
      await _queueRef.doc(uid).set({
        'uid': uid,
        'isTimedMatch': isTimedMatch,
        'timeControlPreset': timeControlPreset,
        'initialMinutes': initialMinutes,
        'incrementSeconds': incrementSeconds,
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
