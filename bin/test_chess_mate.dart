import 'package:chess/chess.dart';
import 'dart:developer' as developer;

void main() {
  const smotheredFen = 'k7/8/8/8/8/8/PPn5/K7 w - - 0 1';
  final chess = Chess.fromFEN(smotheredFen);
  developer.log('in_check: ${chess.in_check}');
  developer.log('in_checkmate: ${chess.in_checkmate}');
  developer.log('moves: ${chess.moves()}');
}
