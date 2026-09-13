import 'package:chess/chess.dart';
import 'dart:developer' as developer;

void main() {
  const rooksFen = '4k3/8/8/8/8/8/K7/R6R w - - 0 1';
  final chess = Chess.fromFEN(rooksFen);
  final move = chess.move('Rae1+');
  developer.log('Move success: $move');
  developer.log('FEN: ${chess.fen}');
}
