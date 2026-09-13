import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:enterprise_chess/core/constants/chess_constants.dart';
import 'package:enterprise_chess/core/errors/app_exceptions.dart';
import 'package:enterprise_chess/core/rules/chess_rules_evaluator.dart';
import 'package:enterprise_chess/models/chess_match.dart';
import 'package:enterprise_chess/models/chess_move.dart';
import 'package:enterprise_chess/models/user_profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:enterprise_chess/services/firestore_service.dart';
import 'package:chess/chess.dart' as chess_lib;

void main() {
  group('Enterprise Chess Engine & Rules Validation Tests', () {
    test('Initial board position is standard FEN and White to move', () {
      final chess = chess_lib.Chess.fromFEN(ChessConstants.initialFen);
      expect(chess.turn, chess_lib.Color.WHITE);
      expect(chess.in_check, isFalse);
      expect(chess.in_checkmate, isFalse);
      expect(chess.in_stalemate, isFalse);
    });

    test('Legal move e2-e4 updates FEN and flips turn to Black', () {
      final chess = chess_lib.Chess.fromFEN(ChessConstants.initialFen);
      final moveRes = chess.move({'from': 'e2', 'to': 'e4'});
      expect(moveRes, isTrue);
      expect(chess.turn, chess_lib.Color.BLACK);
      expect(chess.fen.startsWith('rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3'), isTrue);
    });

    test('Illegal move (e2 to e5) returns false and does not mutate FEN', () {
      final chess = chess_lib.Chess.fromFEN(ChessConstants.initialFen);
      final moveRes = chess.move({'from': 'e2', 'to': 'e5'});
      expect(moveRes, isFalse);
      expect(chess.turn, chess_lib.Color.WHITE);
      expect(chess.fen, ChessConstants.initialFen);
    });

    test("Fool's Mate correctly detects Black checkmate win", () {
      final chess = chess_lib.Chess();
      expect(chess.move({'from': 'f2', 'to': 'f3'}), isTrue);
      expect(chess.move({'from': 'e7', 'to': 'e5'}), isTrue);
      expect(chess.move({'from': 'g2', 'to': 'g4'}), isTrue);
      expect(chess.move({'from': 'd8', 'to': 'h4'}), isTrue);

      expect(chess.in_checkmate, isTrue);
      expect(chess.in_check, isTrue);
      expect(chess.turn, chess_lib.Color.WHITE);
    });

    test("Scholar's Mate correctly detects White checkmate win", () {
      final chess = chess_lib.Chess();
      expect(chess.move({'from': 'e2', 'to': 'e4'}), isTrue);
      expect(chess.move({'from': 'e7', 'to': 'e5'}), isTrue);
      expect(chess.move({'from': 'f1', 'to': 'c4'}), isTrue);
      expect(chess.move({'from': 'b8', 'to': 'c6'}), isTrue);
      expect(chess.move({'from': 'd1', 'to': 'h5'}), isTrue);
      expect(chess.move({'from': 'g8', 'to': 'f6'}), isTrue);
      expect(chess.move({'from': 'h5', 'to': 'f7'}), isTrue);

      expect(chess.in_checkmate, isTrue);
      expect(chess.turn, chess_lib.Color.BLACK);
    });

    test('Stalemate is correctly identified', () {
      const stalemateFen = 'k7/2Q5/8/8/8/8/8/K7 b - - 0 1';
      final chess = chess_lib.Chess.fromFEN(stalemateFen);
      expect(chess.in_stalemate, isTrue);
      expect(chess.in_check, isFalse);
      expect(chess.moves().isEmpty, isTrue);
    });

    group('Insufficient Material Rules (All 4 Cases)', () {
      test('Case 1: King vs King', () {
        const kvkFen = '8/8/8/4k3/8/8/4K3/8 w - - 0 1';
        final chess = chess_lib.Chess.fromFEN(kvkFen);
        expect(ChessRulesEvaluator.isInsufficientMaterial(chess), isTrue);
      });

      test('Case 2: King + Bishop vs King', () {
        const kbvkFen = '8/8/8/4k3/8/5B2/4K3/8 w - - 0 1';
        final chess = chess_lib.Chess.fromFEN(kbvkFen);
        expect(ChessRulesEvaluator.isInsufficientMaterial(chess), isTrue);
      });

      test('Case 3: King + Knight vs King', () {
        const knvkFen = '8/8/8/4k3/8/8/4K3/1N6 w - - 0 1';
        final chess = chess_lib.Chess.fromFEN(knvkFen);
        expect(ChessRulesEvaluator.isInsufficientMaterial(chess), isTrue);
      });

      test('Case 4a: King + Bishop vs King + Bishop (same colored squares)', () {
        // White bishop on c1 (dark square: c=3, 1=1 -> 3+0=3 odd/even? let's check square parity)
        // c1: file 2, rank 0 -> 2+0=2 (dark). f8: file 5, rank 7 -> 5+7=12 (dark). Both dark squares.
        const sameColorBishopsFen = '5b2/8/8/4k3/8/8/4K3/2B5 w - - 0 1';
        final chess = chess_lib.Chess.fromFEN(sameColorBishopsFen);
        expect(ChessRulesEvaluator.isInsufficientMaterial(chess), isTrue);
      });

      test('Case 4b: King + Bishop vs King + Bishop (opposite colored squares) is NOT insufficient', () {
        // White bishop on c1 (dark), Black bishop on e8 (light: file 4, rank 7 -> 4+7=11).
        const diffColorBishopsFen = '4b3/8/8/4k3/8/8/4K3/2B5 w - - 0 1';
        final chess = chess_lib.Chess.fromFEN(diffColorBishopsFen);
        expect(ChessRulesEvaluator.isInsufficientMaterial(chess), isFalse);
      });

      test('Pawn present is never insufficient material', () {
        const pawnFen = '8/4p3/8/4k3/8/8/4K3/8 w - - 0 1';
        final chess = chess_lib.Chess.fromFEN(pawnFen);
        expect(ChessRulesEvaluator.isInsufficientMaterial(chess), isFalse);
      });
    });

    group('Threefold Repetition Evaluator Tests', () {
      test('Identifies threefold repetition accurately when position occurs 3 times', () {
        const fen1 = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
        const fen2 = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';

        final history = [fen1, fen2, fen1, fen2, fen1];
        expect(ChessRulesEvaluator.isThreefoldRepetition(fen1, history), isTrue);
      });

      test('Returns false when position has only occurred 2 times', () {
        const fen1 = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
        const fen2 = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';

        final history = [fen1, fen2, fen1, fen2];
        expect(ChessRulesEvaluator.isThreefoldRepetition(fen1, history), isFalse);
      });
    });

    test('Castling kingside and queenside updates castling rights', () {
      const readyToCastleFen = 'r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1';
      final chess = chess_lib.Chess.fromFEN(readyToCastleFen);
      final castled = chess.move({'from': 'e1', 'to': 'g1'});
      expect(castled, isTrue);
      expect(chess.fen.contains('KQ'), isFalse);
      expect(chess.fen.contains('kq'), isTrue);
    });

    test('Pawn promotion with choice is properly processed', () {
      const promotionFen = '8/4P3/8/8/8/8/8/k6K w - - 0 1';
      final chess = chess_lib.Chess.fromFEN(promotionFen);
      final promoted = chess.move({'from': 'e7', 'to': 'e8', 'promotion': 'q'});
      expect(promoted, isTrue);
      expect(chess.get('e8')?.type.name, 'q');
    });

    group('Castling Preconditions', () {
      test('Castling rejected if King is in check', () {
        const checkFen = 'r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1';
        final chess = chess_lib.Chess.fromFEN(checkFen);
        // Put white king in check
        chess.put(chess_lib.Piece(chess_lib.PieceType.ROOK, chess_lib.Color.BLACK), 'e2');
        expect(chess.in_check, isTrue);
        expect(chess.move({'from': 'e1', 'to': 'g1'}), isFalse); // kingside rejected
        expect(chess.move({'from': 'e1', 'to': 'c1'}), isFalse); // queenside rejected
      });

      test('Castling rejected if King passes through check', () {
        const passCheckFen = 'r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1';
        final chess = chess_lib.Chess.fromFEN(passCheckFen);
        // Put a black rook on f8 attacking f1 (passing square for kingside)
        chess.put(chess_lib.Piece(chess_lib.PieceType.ROOK, chess_lib.Color.BLACK), 'f8');
        expect(chess.move({'from': 'e1', 'to': 'g1'}), isFalse); // kingside rejected
      });

      test('Castling rejected if King lands in check', () {
        const landCheckFen = 'r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1';
        final chess = chess_lib.Chess.fromFEN(landCheckFen);
        // Put a black rook on g8 attacking g1 (landing square for kingside)
        chess.put(chess_lib.Piece(chess_lib.PieceType.ROOK, chess_lib.Color.BLACK), 'g8');
        expect(chess.move({'from': 'e1', 'to': 'g1'}), isFalse); // kingside rejected
      });

      test('Castling rejected if pieces are between King and Rook', () {
        const blockedFen = 'r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1';
        final chess = chess_lib.Chess.fromFEN(blockedFen);
        // Block kingside
        chess.put(chess_lib.Piece(chess_lib.PieceType.KNIGHT, chess_lib.Color.WHITE), 'f1');
        expect(chess.move({'from': 'e1', 'to': 'g1'}), isFalse);
      });
    });

    test('En passant right expires if not taken immediately', () {
      final chess = chess_lib.Chess();
      expect(chess.move({'from': 'e2', 'to': 'e4'}), isTrue);
      expect(chess.move({'from': 'a7', 'to': 'a6'}), isTrue);
      expect(chess.move({'from': 'e4', 'to': 'e5'}), isTrue);
      // Black moves pawn two squares
      expect(chess.move({'from': 'd7', 'to': 'd5'}), isTrue);
      // White could play en passant now (exd6), but makes a different move
      expect(chess.move({'from': 'h2', 'to': 'h3'}), isTrue);
      expect(chess.move({'from': 'a6', 'to': 'a5'}), isTrue);
      // Now White tries en passant -> should fail
      expect(chess.move({'from': 'e5', 'to': 'd6'}), isFalse);
    });

    test('Pinned piece self-check is illegal', () {
      const pinFen = 'k7/8/8/8/8/8/4R3/4K3 b - - 0 1';
      final chess = chess_lib.Chess.fromFEN(pinFen);
      // Put black rook on e8, pinning white rook on e2 to white king on e1
      chess.put(chess_lib.Piece(chess_lib.PieceType.ROOK, chess_lib.Color.BLACK), 'e8');
      chess.turn = chess_lib.Color.WHITE; // White to move
      // Moving rook off the e-file exposes king to check
      expect(chess.move({'from': 'e2', 'to': 'f2'}), isFalse);
      expect(chess.move({'from': 'e2', 'to': 'e3'}), isTrue); // moving along the pin is legal
    });

    test('Smothered mate is correctly detected', () {
      // Classic smothered mate pattern via legal move sequence
      final chess = chess_lib.Chess();
      final moves = ['e4', 'e5', 'Nf3', 'Nc6', 'Bc4', 'Nd4', 'Nxe5', 'Qg5', 'Nxf7', 'Qxg2', 'Rf1', 'Qxe4+', 'Be2', 'Nf3#'];
      for (final move in moves) {
        chess.move(move);
      }
      expect(chess.in_checkmate, isTrue);
    });

    test('SAN disambiguation generates correct notation', () {
      // Two white rooks on a1 and h1, black king on e8, white king on a2
      const rooksFen = '4k3/8/8/8/8/8/K7/R6R w - - 0 1';
      final chess = chess_lib.Chess.fromFEN(rooksFen);
      // If we pass a disambiguated SAN, the engine must correctly parse and apply it
      final move = chess.move('Rae1+');
      expect(move, isTrue);
      // The FEN should reflect that the a1 rook moved to e1
      expect(chess.fen.startsWith('4k3/8/8/8/8/8/K7/4R2R'), isTrue);
    });
  });

  group('Firestore Transaction & Security Constraints Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FirestoreService firestoreService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      firestoreService = FirestoreService(firestore: fakeFirestore);
    });

    test('Creates match doc with accurate server initial state', () async {
      final match = await firestoreService.createMatch(
        whiteUid: 'user_white',
        blackUid: 'user_black',
        matchType: 'human',
        timeControlMillis: 600000,
      );

      expect(match.matchId.isNotEmpty, isTrue);
      expect(match.whiteUid, 'user_white');
      expect(match.blackUid, 'user_black');
      expect(match.activeTurn, 'w');
      expect(match.status, MatchStatus.active);
      expect(match.whiteMillisRemaining, 600000);
      expect(match.blackMillisRemaining, 600000);
      expect(match.positionHistory.length, 1);
      expect(match.processedClientMoveIds.isEmpty, isTrue);
    });

    test('Submits legal move transaction successfully and writes immutable move record', () async {
      final match = await firestoreService.createMatch(
        whiteUid: 'user_white',
        blackUid: 'user_black',
        matchType: 'human',
        timeControlMillis: 600000,
      );

      final chess = chess_lib.Chess.fromFEN(match.currentFen);
      chess.move({'from': 'e2', 'to': 'e4'});

      await firestoreService.submitMoveTransaction(
        matchId: match.matchId,
        playerUid: 'user_white',
        newFen: chess.fen,
        san: 'e4',
        moveNumber: 1,
        isCheck: false,
        isCheckmate: false,
        newStatus: MatchStatus.active,
        clientMoveId: 'client-move-uuid-1',
        fromSquare: 'e2',
        toSquare: 'e4',
        useLocalFallback: true,
      );

      // Verify match state updated
      final updatedDoc = await fakeFirestore
          .collection(ChessConstants.matchesCollection)
          .doc(match.matchId)
          .get();

      final updatedMatch = ChessMatch.fromJson(updatedDoc.data()!);
      expect(updatedMatch.activeTurn, 'b');
      expect(updatedMatch.currentFen, chess.fen);
      expect(updatedMatch.lastMoveSan, 'e4');
      expect(updatedMatch.processedClientMoveIds.contains('client-move-uuid-1'), isTrue);

      // Verify moves subcollection entry
      final moveDocs = await fakeFirestore
          .collection(ChessConstants.matchesCollection)
          .doc(match.matchId)
          .collection(ChessConstants.movesSubcollection)
          .get();

      expect(moveDocs.docs.length, 1);
      final moveRecord = ChessMove.fromJson(moveDocs.docs.first.data());
      expect(moveRecord.san, 'e4');
      expect(moveRecord.movedBy, 'user_white');
      expect(moveRecord.moveNumber, 1);
      expect(moveRecord.clientMoveId, 'client-move-uuid-1');
    });

    test('Replay attack / duplicate clientMoveId is rejected with DuplicateMoveException', () async {
      final match = await firestoreService.createMatch(
        whiteUid: 'user_white',
        blackUid: 'user_black',
        matchType: 'human',
        timeControlMillis: 600000,
      );

      final chess = chess_lib.Chess.fromFEN(match.currentFen);
      chess.move({'from': 'e2', 'to': 'e4'});

      // First submit
      await firestoreService.submitMoveTransaction(
        matchId: match.matchId,
        playerUid: 'user_white',
        newFen: chess.fen,
        san: 'e4',
        moveNumber: 1,
        isCheck: false,
        isCheckmate: false,
        newStatus: MatchStatus.active,
        clientMoveId: 'client-move-uuid-1',
        fromSquare: 'e2',
        toSquare: 'e4',
        useLocalFallback: true,
      );

      // Second submit with identical clientMoveId must be rejected
      expect(
        () async => await firestoreService.submitMoveTransaction(
          matchId: match.matchId,
          playerUid: 'user_white',
          newFen: chess.fen,
          san: 'e4',
          moveNumber: 1,
          isCheck: false,
          isCheckmate: false,
          newStatus: MatchStatus.active,
          clientMoveId: 'client-move-uuid-1',
          fromSquare: 'e2',
          toSquare: 'e4',
          useLocalFallback: true,
        ),
        throwsA(isA<DuplicateMoveException>()),
      );
    });

    test('Transaction rejects move submitted out of turn with OutOfTurnException', () async {
      final match = await firestoreService.createMatch(
        whiteUid: 'user_white',
        blackUid: 'user_black',
        matchType: 'human',
        timeControlMillis: 600000,
      );

      final chess = chess_lib.Chess.fromFEN(match.currentFen);
      chess.move({'from': 'e2', 'to': 'e4'});

      // Black attempts to move while it is White's turn
      expect(
        () async => await firestoreService.submitMoveTransaction(
          matchId: match.matchId,
          playerUid: 'user_black',
          newFen: chess.fen,
          san: 'e4',
          moveNumber: 1,
          isCheck: false,
          isCheckmate: false,
          newStatus: MatchStatus.active,
          clientMoveId: 'client-move-uuid-1',
          fromSquare: 'e2',
          toSquare: 'e4',
          useLocalFallback: true,
        ),
        throwsA(isA<OutOfTurnException>()),
      );
    });

    test('Transaction rejects move submitted by non-participant with OutOfTurnException', () async {
      final match = await firestoreService.createMatch(
        whiteUid: 'user_white',
        blackUid: 'user_black',
        matchType: 'human',
      );

      expect(
        () async => await firestoreService.submitMoveTransaction(
          matchId: match.matchId,
          playerUid: 'imposter_uid',
          newFen: 'fake_fen',
          san: 'e4',
          fromSquare: 'e2',
          toSquare: 'e4',
          moveNumber: 1,
          isCheck: false,
          isCheckmate: false,
          newStatus: MatchStatus.active,
          clientMoveId: 'client-move-3',
        ),
        throwsA(isA<OutOfTurnException>()),
      );
    });

    test('Banned player is rejected from matchmaking and match creation', () async {
      // Save banned profile
      await firestoreService.saveUserProfile(UserProfile(
        uid: 'banned_user',
        displayName: 'Cheater',
        eloRating: 1200,
        gamesPlayed: 10,
        wins: 0,
        losses: 10,
        draws: 0,
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
        isBanned: true,
      ));

      expect(
        () async => await firestoreService.createMatch(
          whiteUid: 'banned_user',
          blackUid: 'innocent_user',
          matchType: 'human',
        ),
        throwsA(isA<AuthRequiredException>()),
      );

      expect(
        () async => await firestoreService.findOrCreateMatchmakingMatch(
          uid: 'banned_user',
          timeControlMillis: 600000,
          isTimedMatch: true,
        ),
        throwsA(isA<AuthRequiredException>()),
      );
    });

    test('Resignation updates match status and sets winner', () async {
      final match = await firestoreService.createMatch(
        whiteUid: 'user_white',
        blackUid: 'user_black',
        matchType: 'human',
      );

      await firestoreService.resignMatch(matchId: match.matchId, resigningUid: 'user_white');

      final updatedDoc = await fakeFirestore
          .collection(ChessConstants.matchesCollection)
          .doc(match.matchId)
          .get();

      final updatedMatch = ChessMatch.fromJson(updatedDoc.data()!);
      expect(updatedMatch.status, MatchStatus.resignation);
      expect(updatedMatch.winnerUid, 'user_black');
    });

    test('Untimed match abandonment claim succeeds after 24 hours', () async {
      final match = await firestoreService.createMatch(
        whiteUid: 'user_white',
        blackUid: 'user_black',
        matchType: 'human',
        isTimedMatch: false,
      );

      // Force lastMoveServerTimestamp to 25 hours ago
      final pastDate = DateTime.now().subtract(const Duration(hours: 25));
      await fakeFirestore
          .collection(ChessConstants.matchesCollection)
          .doc(match.matchId)
          .update({'lastMoveServerTimestamp': Timestamp.fromDate(pastDate)});

      // It's White's turn, so Black claims abandonment
      await firestoreService.claimAbandonment(matchId: match.matchId, claimantUid: 'user_black');

      final updatedDoc = await fakeFirestore
          .collection(ChessConstants.matchesCollection)
          .doc(match.matchId)
          .get();

      final updatedMatch = ChessMatch.fromJson(updatedDoc.data()!);
      expect(updatedMatch.status, MatchStatus.abandoned);
      expect(updatedMatch.winnerUid, 'user_black');
    });

    test('Untimed match abandonment claim fails if less than 24 hours', () async {
      final match = await firestoreService.createMatch(
        whiteUid: 'user_white',
        blackUid: 'user_black',
        matchType: 'human',
        isTimedMatch: false,
      );

      // Force lastMoveServerTimestamp to 1 hour ago
      final pastDate = DateTime.now().subtract(const Duration(hours: 1));
      await fakeFirestore
          .collection(ChessConstants.matchesCollection)
          .doc(match.matchId)
          .update({'lastMoveServerTimestamp': Timestamp.fromDate(pastDate)});

      // Black tries to claim
      await firestoreService.claimAbandonment(matchId: match.matchId, claimantUid: 'user_black');

      final updatedDoc = await fakeFirestore
          .collection(ChessConstants.matchesCollection)
          .doc(match.matchId)
          .get();

      final updatedMatch = ChessMatch.fromJson(updatedDoc.data()!);
      // Status should remain active
      expect(updatedMatch.status, MatchStatus.active);
      expect(updatedMatch.winnerUid, isNull);
    });

    test('Claim timeout sets status to whiteTimeout / blackTimeout', () async {
      final match = await firestoreService.createMatch(
        whiteUid: 'user_white',
        blackUid: 'user_black',
        matchType: 'human',
      );

      await firestoreService.claimTimeout(
        matchId: match.matchId,
        timedOutColor: 'w',
      );

      final doc = await fakeFirestore
          .collection(ChessConstants.matchesCollection)
          .doc(match.matchId)
          .get();
      final updatedMatch = ChessMatch.fromJson(doc.data()!);

      expect(updatedMatch.status, MatchStatus.whiteTimeout);
      expect(updatedMatch.winnerUid, 'user_black');
    });
  });
}
