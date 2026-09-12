import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_chess/models/chess_match.dart';
import 'package:enterprise_chess/models/chess_move.dart';
import 'package:enterprise_chess/services/pgn_service.dart';

void main() {
  group('PgnService Unit Tests', () {
    test('Generates valid 7-tag roster PGN for White victory', () {
      final now = DateTime(2026, 9, 12);
      final match = ChessMatch(
        matchId: 'match_123',
        whiteUid: 'uid_white',
        blackUid: 'uid_black',
        status: MatchStatus.whiteWonCheckmate,
        currentFen: 'rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3',
        activeTurn: 'w',
        whiteMillisRemaining: 175000,
        blackMillisRemaining: 178000,
        lastMoveServerTimestamp: now,
        createdAt: now,
        matchType: 'human',
      );

      final moves = [
        ChessMove(
          moveNumber: 1,
          san: 'f3',
          fenAfterMove: 'rnbqkbnr/pppppppp/8/8/8/5P2/PPPPP1PP/RNBQKBNR b KQkq - 0 1',
          serverTimestamp: now,
          movedBy: 'uid_white',
          isCheck: false,
          isCheckmate: false,
          clientMoveId: 'c1',
        ),
        ChessMove(
          moveNumber: 2,
          san: 'e5',
          fenAfterMove: 'rnbqkbnr/pppp1ppp/8/4p3/8/5P2/PPPPP1PP/RNBQKBNR w KQkq e6 0 2',
          serverTimestamp: now,
          movedBy: 'uid_black',
          isCheck: false,
          isCheckmate: false,
          clientMoveId: 'c2',
        ),
      ];

      final pgn = PgnService.generatePgn(
        match: match,
        moves: moves,
        whiteName: 'Magnus',
        blackName: 'Hikaru',
        whiteElo: 2850,
        blackElo: 2800,
      );

      expect(pgn, contains('[Event "Enterprise Chess Match"]'));
      expect(pgn, contains('[White "Magnus"]'));
      expect(pgn, contains('[Black "Hikaru"]'));
      expect(pgn, contains('[Result "1-0"]'));
      expect(pgn, contains('[WhiteElo "2850"]'));
      expect(pgn, contains('[BlackElo "2800"]'));
      expect(pgn, contains('1. f3 e5 1-0'));
    });

    test('Formats draw result correctly as 1/2-1/2', () {
      final now = DateTime(2026, 9, 12);
      final match = ChessMatch(
        matchId: 'match_draw',
        whiteUid: 'uid_1',
        blackUid: 'uid_2',
        status: MatchStatus.drawStalemate,
        currentFen: '8/8/8/8/8/5k2/5q2/7K w - - 0 1',
        activeTurn: 'w',
        whiteMillisRemaining: 100000,
        blackMillisRemaining: 100000,
        lastMoveServerTimestamp: now,
        createdAt: now,
        matchType: 'human',
      );

      final pgn = PgnService.generatePgn(
        match: match,
        moves: [],
      );

      expect(pgn, contains('[Result "1/2-1/2"]'));
      expect(pgn.endsWith('1/2-1/2'), isTrue);
    });
  });
}
