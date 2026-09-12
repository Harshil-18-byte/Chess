import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/chess_match.dart';
import '../models/chess_move.dart';

/// Service for generating and exporting standard Portable Game Notation (PGN) and FEN.
class PgnService {
  /// Generates a standardized PGN string adhering to FIDE / 7-Tag Roster standards.
  static String generatePgn({
    required ChessMatch match,
    required List<ChessMove> moves,
    String? whiteName,
    String? blackName,
    int? whiteElo,
    int? blackElo,
  }) {
    final buffer = StringBuffer();
    final dateStr = DateFormat('yyyy.MM.dd').format(match.createdAt);

    // Determine result string
    String resultStr = '*';
    switch (match.status) {
      case MatchStatus.whiteWonCheckmate:
      case MatchStatus.blackTimeout:
        resultStr = '1-0';
        break;
      case MatchStatus.blackWonCheckmate:
      case MatchStatus.whiteTimeout:
        resultStr = '0-1';
        break;
      case MatchStatus.resignation:
        resultStr = match.winnerUid == match.whiteUid ? '1-0' : '0-1';
        break;
      case MatchStatus.drawStalemate:
      case MatchStatus.drawThreefoldRepetition:
      case MatchStatus.drawFiftyMoveRule:
      case MatchStatus.drawInsufficientMaterial:
        resultStr = '1/2-1/2';
        break;
      default:
        resultStr = '*';
    }

    // 7-Tag Roster
    buffer.writeln('[Event "Enterprise Chess Match"]');
    buffer.writeln('[Site "Enterprise Chess Platform"]');
    buffer.writeln('[Date "$dateStr"]');
    buffer.writeln('[Round "1"]');
    buffer.writeln('[White "${whiteName ?? match.whiteUid}"]');
    buffer.writeln('[Black "${blackName ?? match.blackUid}"]');
    buffer.writeln('[Result "$resultStr"]');

    if (whiteElo != null) buffer.writeln('[WhiteElo "$whiteElo"]');
    if (blackElo != null) buffer.writeln('[BlackElo "$blackElo"]');
    if (match.whiteMillisRemaining > 0) {
      buffer.writeln('[TimeControl "${match.whiteMillisRemaining ~/ 1000}"]');
    }
    buffer.writeln();

    // Format moves in standard SAN pairs: 1. e4 e5 2. Nf3 Nc6
    var moveIndex = 1;
    for (var i = 0; i < moves.length; i += 2) {
      final whiteMove = moves[i].san;
      if (i + 1 < moves.length) {
        final blackMove = moves[i + 1].san;
        buffer.write('$moveIndex. $whiteMove $blackMove ');
      } else {
        buffer.write('$moveIndex. $whiteMove ');
      }
      moveIndex++;
    }

    buffer.write(resultStr);
    return buffer.toString().trim();
  }

  /// Copies PGN content to user's system clipboard.
  static Future<void> copyPgnToClipboard(String pgn) async {
    await Clipboard.setData(ClipboardData(text: pgn));
  }

  /// Copies FEN string to user's system clipboard.
  static Future<void> copyFenToClipboard(String fen) async {
    await Clipboard.setData(ClipboardData(text: fen));
  }
}
