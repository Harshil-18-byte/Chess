import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_chess/core/rules/material_calculator.dart';

void main() {
  group('MaterialScore Calculator Unit Tests', () {
    test('Initial starting position has 0 captured pieces and 0 advantage', () {
      const startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
      final score = MaterialScore.fromFen(startFen);

      expect(score.whiteCapturedPieces, isEmpty);
      expect(score.blackCapturedPieces, isEmpty);
      expect(score.whiteValue, equals(39));
      expect(score.blackValue, equals(39));
      expect(score.whiteAdvantage, equals(0));
      expect(score.blackAdvantage, equals(0));
    });

    test('Detects captured black queen and pawn when missing from FEN', () {
      // FEN where black is missing queen and 1 pawn
      const customFen = 'rnb1kbnr/ppppppp1/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
      final score = MaterialScore.fromFen(customFen);

      expect(score.whiteCapturedPieces, containsAll(['q', 'p']));
      expect(score.whiteCapturedPieces.length, equals(2));
      expect(score.blackCapturedPieces, isEmpty);
      expect(score.whiteAdvantage, equals(10)); // 9 (queen) + 1 (pawn)
      expect(score.blackAdvantage, equals(-10));
    });

    test('Detects captured white rook and knight when missing from FEN', () {
      // FEN where white is missing 1 rook and 1 knight
      const customFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/R1BQKBN1 w Qkq - 0 1';
      final score = MaterialScore.fromFen(customFen);

      expect(score.blackCapturedPieces, containsAll(['R', 'N']));
      expect(score.blackCapturedPieces.length, equals(2));
      expect(score.whiteCapturedPieces, isEmpty);
      expect(score.whiteAdvantage, equals(-8)); // 5 (rook) + 3 (knight)
      expect(score.blackAdvantage, equals(8));
    });

    test('Maps unicode piece symbols accurately', () {
      expect(MaterialScore.getPieceSymbol('p'), equals('♟'));
      expect(MaterialScore.getPieceSymbol('q'), equals('♛'));
      expect(MaterialScore.getPieceSymbol('P'), equals('♙'));
      expect(MaterialScore.getPieceSymbol('Q'), equals('♕'));
    });
  });
}
