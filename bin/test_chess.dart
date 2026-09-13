import 'package:chess/chess.dart';
import 'dart:developer' as developer;

void main() {
  final chess = Chess();
  chess.move({'from': 'e2', 'to': 'e4'});
  developer.log('history: ${chess.history}');
  developer.log('history last toString: ${chess.history.last.toString()}');
}
