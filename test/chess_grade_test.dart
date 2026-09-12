import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_chess/models/chess_grade.dart';

void main() {
  group('ChessGrade Domain Model Tests', () {
    test('Verifies all 6 grades are defined in correct hierarchy', () {
      expect(ChessGrade.values.length, 6);
      expect(ChessGrade.values, [
        ChessGrade.beginner,
        ChessGrade.novice,
        ChessGrade.intermediate,
        ChessGrade.advanced,
        ChessGrade.master,
        ChessGrade.grandmaster,
      ]);
    });

    test('Maps Elo ratings accurately to respective grades via fromElo', () {
      expect(ChessGrade.fromElo(500), ChessGrade.beginner);
      expect(ChessGrade.fromElo(799), ChessGrade.beginner);
      expect(ChessGrade.fromElo(800), ChessGrade.novice);
      expect(ChessGrade.fromElo(1199), ChessGrade.novice);
      expect(ChessGrade.fromElo(1200), ChessGrade.intermediate);
      expect(ChessGrade.fromElo(1599), ChessGrade.intermediate);
      expect(ChessGrade.fromElo(1600), ChessGrade.advanced);
      expect(ChessGrade.fromElo(1999), ChessGrade.advanced);
      expect(ChessGrade.fromElo(2000), ChessGrade.master);
      expect(ChessGrade.fromElo(2399), ChessGrade.master);
      expect(ChessGrade.fromElo(2400), ChessGrade.grandmaster);
      expect(ChessGrade.fromElo(2850), ChessGrade.grandmaster);
    });

    test('Validates Stockfish UCI skill levels fall within legal range 0-20', () {
      for (final grade in ChessGrade.values) {
        expect(grade.stockfishSkill, greaterThanOrEqualTo(0));
        expect(grade.stockfishSkill, lessThanOrEqualTo(20));
        expect(grade.engineMoveTimeMillis, greaterThan(0));
        expect(grade.iconSymbol.isNotEmpty, isTrue);
        expect(grade.title.isNotEmpty, isTrue);
        expect(grade.description.isNotEmpty, isTrue);
      }
    });

    test('Verifies increasing skill levels and Elo with rank hierarchy', () {
      for (int i = 0; i < ChessGrade.values.length - 1; i++) {
        final current = ChessGrade.values[i];
        final next = ChessGrade.values[i + 1];
        expect(next.elo, greaterThan(current.elo));
        expect(next.stockfishSkill, greaterThan(current.stockfishSkill));
      }
    });
  });
}
