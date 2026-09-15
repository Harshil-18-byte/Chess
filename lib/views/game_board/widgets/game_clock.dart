import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/chess_constants.dart';
import '../../../core/theme/board_themes.dart';

/// Highly precise digital timer component.
class GameClock extends StatefulWidget {
  final int millisecondsLeft;
  final bool isRunning;
  final Color activeColor;
  final VoidCallback? onTimeout;

  const GameClock({
    super.key,
    required this.millisecondsLeft,
    required this.isRunning,
    required this.activeColor,
    this.onTimeout,
  });

  @override
  State<GameClock> createState() => _GameClockState();
}

class _GameClockState extends State<GameClock> {
  late int _currentMillis;
  Timer? _ticker;
  bool _hasTimedOut = false;

  @override
  void initState() {
    super.initState();
    _currentMillis = widget.millisecondsLeft;
    if (widget.isRunning) _startClock();
  }

  @override
  void didUpdateWidget(covariant GameClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.millisecondsLeft != widget.millisecondsLeft) {
      _currentMillis = widget.millisecondsLeft;
      if (_currentMillis > 0) _hasTimedOut = false;
    }
    if (oldWidget.isRunning != widget.isRunning) {
      widget.isRunning ? _startClock() : _stopClock();
    }
  }

  @override
  void dispose() {
    _stopClock();
    super.dispose();
  }

  void _startClock() {
    _stopClock();
    if (_currentMillis <= 0) return;
    
    // Switch to high-frequency updates if remaining time is critically low
    final duration = _currentMillis < 10000 ? const Duration(milliseconds: 100) : const Duration(seconds: 1);
    _ticker = Timer.periodic(duration, (timer) {
      setState(() {
        if (_currentMillis <= 0) {
          _currentMillis = 0;
          _stopClock();
          if (!_hasTimedOut) {
            _hasTimedOut = true;
            widget.onTimeout?.call();
          }
        } else {
          _currentMillis -= duration.inMilliseconds;
        }
      });
      // Adjust ticker frequency dynamically if crossing threshold
      if (_currentMillis < 10000 && duration.inMilliseconds == 1000) {
        _startClock(); 
      }
    });
  }

  void _stopClock() {
    _ticker?.cancel();
  }

  String _formatTime(int totalMillis) {
    if (totalMillis <= 0) return "00:00.0";
    final int minutes = (totalMillis / 60000).floor();
    final int seconds = ((totalMillis % 60000) / 1000).floor();
    
    if (totalMillis < 10000) {
      final int tenths = ((totalMillis % 1000) / 100).floor();
      return "${seconds.toString().padLeft(2, '0')}.${tenths.toString()}";
    }
    
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final bool isCritical = _currentMillis < 10000;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: widget.isRunning ? widget.activeColor : BoardThemes.midSlate,
          width: 1,
        ),
      ),
      child: Text(
        _formatTime(_currentMillis),
        style: TextStyle(
          color: isCritical && widget.isRunning ? BoardThemes.brandEmber : BoardThemes.pureWhite,
          fontFamily: 'Courier',
          fontSize: 18,
          fontWeight: FontWeight.bold,
          shadows: widget.isRunning ? [
            Shadow(
              color: widget.activeColor.withAlpha(128), // 0.5 opacity
              blurRadius: 8,
            )
          ] : null,
        ),
      ),
    );
  }
}

/// Renders a responsive player clock wrapper for both sides, managing active layout states.
class GameClockWidget extends StatelessWidget {
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

  Widget _buildClockCard({
    required String name,
    required int elo,
    required int millis,
    required bool isActiveTurn,
    required bool isWhite,
  }) {
    final isLowTime = millis < ChessConstants.lowTimeWarningThresholdMillis;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: BoardThemes.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActiveTurn
              ? (isLowTime ? BoardThemes.midSlate : BoardThemes.pureWhite)
              : BoardThemes.borderSubtle,
          width: isActiveTurn ? 2.0 : 1.0,
        ),
        boxShadow: isActiveTurn && !isLowTime
            ? [
                BoxShadow(
                  color: BoardThemes.pureWhite.withAlpha(20),
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
                      color: isWhite ? BoardThemes.pureWhite : BoardThemes.pitchBlack,
                      shape: BoxShape.circle,
                      border: Border.all(color: BoardThemes.mutedSilver, width: 1),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: BoardThemes.pureWhite,
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
          // Precise Digital Timer
          GameClock(
            millisecondsLeft: millis,
            isRunning: isActiveTurn && isMatchActive,
            activeColor: isWhite ? const Color(0xFFF59E0B) : BoardThemes.brandEmber,
            onTimeout: onTimeout,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWhitePlayer = playerColor == 'w';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left: White Player
        _buildClockCard(
          name: isWhitePlayer ? playerName : opponentName,
          elo: isWhitePlayer ? playerElo : opponentElo,
          millis: whiteMillisRemaining,
          isActiveTurn: activeTurn == 'w' && isMatchActive,
          isWhite: true,
        ),
        // Right: Black Player
        _buildClockCard(
          name: isWhitePlayer ? opponentName : playerName,
          elo: isWhitePlayer ? opponentElo : playerElo,
          millis: blackMillisRemaining,
          isActiveTurn: activeTurn == 'b' && isMatchActive,
          isWhite: false,
        ),
      ],
    );
  }
}
