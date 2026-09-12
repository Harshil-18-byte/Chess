import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/chess_constants.dart';
import '../../../core/theme/board_themes.dart';

/// Renders a responsive player clock with 100ms visual ticker and authoritative Firestore resyncing.
class GameClockWidget extends StatefulWidget {
  final int whiteMillisRemaining;
  final int blackMillisRemaining;
  final String activeTurn; // 'w' or 'b'
  final bool isMatchActive;
  final String playerName;
  final String opponentName;
  final String playerColor; // 'w' or 'b'
  final int playerElo;
  final int opponentElo;
  final VoidCallback? onTimeout;

  const GameClockWidget({
    super.key,
    required this.whiteMillisRemaining,
    required this.blackMillisRemaining,
    required this.activeTurn,
    required this.isMatchActive,
    required this.playerName,
    required this.opponentName,
    required this.playerColor,
    this.playerElo = 1200,
    this.opponentElo = 1200,
    this.onTimeout,
  });

  @override
  State<GameClockWidget> createState() => _GameClockWidgetState();
}

class _GameClockWidgetState extends State<GameClockWidget> {
  Timer? _ticker;
  late int _whiteMillis;
  late int _blackMillis;
  DateTime _lastTickTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _resyncAuthoritativeClocks();
    _startLocalTicker();
  }

  @override
  void didUpdateWidget(covariant GameClockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Instant snap-to-authoritative server time on snapshot arrival
    if (oldWidget.whiteMillisRemaining != widget.whiteMillisRemaining ||
        oldWidget.blackMillisRemaining != widget.blackMillisRemaining ||
        oldWidget.activeTurn != widget.activeTurn ||
        oldWidget.isMatchActive != widget.isMatchActive) {
      _resyncAuthoritativeClocks();
    }
  }

  void _resyncAuthoritativeClocks() {
    _whiteMillis = widget.whiteMillisRemaining;
    _blackMillis = widget.blackMillisRemaining;
    _lastTickTime = DateTime.now();
  }

  void _startLocalTicker() {
    _ticker?.cancel();
    if (!widget.isMatchActive) return;

    _ticker = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!widget.isMatchActive || !mounted) return;

      final now = DateTime.now();
      final elapsed = now.difference(_lastTickTime).inMilliseconds;
      _lastTickTime = now;

      setState(() {
        if (widget.activeTurn == 'w') {
          _whiteMillis = (_whiteMillis - elapsed).clamp(0, 86400000);
          if (_whiteMillis <= 0) {
            timer.cancel();
            widget.onTimeout?.call();
          }
        } else {
          _blackMillis = (_blackMillis - elapsed).clamp(0, 86400000);
          if (_blackMillis <= 0) {
            timer.cancel();
            widget.onTimeout?.call();
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _formatTime(int millis) {
    final totalSeconds = (millis / 1000).ceil();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final tenths = (millis % 1000) ~/ 100;

    final minStr = minutes.toString().padLeft(2, '0');
    final secStr = seconds.toString().padLeft(2, '0');

    if (totalSeconds < 20 && widget.isMatchActive) {
      return '$minStr:$secStr.$tenths';
    }
    return '$minStr:$secStr';
  }

  Widget _buildClockCard({
    required String name,
    required int elo,
    required int millis,
    required bool isActiveTurn,
    required bool isWhite,
  }) {
    final isLowTime = millis < ChessConstants.lowTimeWarningThresholdMillis;

    Color badgeBg;
    Color textColor;
    if (isActiveTurn) {
      badgeBg = isLowTime ? BoardThemes.dangerAlert : BoardThemes.accentCyan;
      textColor = Colors.black;
    } else {
      badgeBg = BoardThemes.surfaceCard;
      textColor = isLowTime ? BoardThemes.accentRose : Colors.white;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: BoardThemes.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActiveTurn
              ? (isLowTime ? BoardThemes.dangerAlert : BoardThemes.accentCyan)
              : BoardThemes.borderSubtle,
          width: isActiveTurn ? 2.0 : 1.0,
        ),
        boxShadow: isActiveTurn
            ? [
                BoxShadow(
                  color: (isLowTime ? BoardThemes.dangerAlert : BoardThemes.accentCyan)
                      .withAlpha(80),
                  blurRadius: 10,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Player info
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isWhite ? Colors.white : Colors.black,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade400, width: 1),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Text(
                '$elo Elo',
                style: BoardThemes.bodyRegular.copyWith(fontSize: 11),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Clock Digits Display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _formatTime(millis),
              style: BoardThemes.clockDigits.copyWith(
                color: textColor,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWhitePlayer = widget.playerColor == 'w';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left: White Player
        _buildClockCard(
          name: isWhitePlayer ? widget.playerName : widget.opponentName,
          elo: isWhitePlayer ? widget.playerElo : widget.opponentElo,
          millis: _whiteMillis,
          isActiveTurn: widget.activeTurn == 'w' && widget.isMatchActive,
          isWhite: true,
        ),
        // Right: Black Player
        _buildClockCard(
          name: isWhitePlayer ? widget.opponentName : widget.playerName,
          elo: isWhitePlayer ? widget.opponentElo : widget.playerElo,
          millis: _blackMillis,
          isActiveTurn: widget.activeTurn == 'b' && widget.isMatchActive,
          isWhite: false,
        ),
      ],
    );
  }
}
