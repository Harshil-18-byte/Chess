import 'dart:math' as math;
import 'package:flutter/material.dart';

/// State of an active 3D move animation.
class Active3DMoveAnimation {
  final String pieceChar;
  final String fromSquare;
  final String toSquare;
  final String? capturedPiece;
  final double progress; // 0.0 to 1.0

  const Active3DMoveAnimation({
    required this.pieceChar,
    required this.fromSquare,
    required this.toSquare,
    this.capturedPiece,
    required this.progress,
  });

  /// Computes current 3D position offset (dx, dy, elevationZ) along parabolic arc.
  ({double dx, double dy, double elevation}) computeInterpolatedPosition({
    required bool isFlipped,
  }) {
    final fromFile = fromSquare.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final fromRank = int.parse(fromSquare[1]) - 1;
    final toFile = toSquare.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final toRank = int.parse(toSquare[1]) - 1;

    final startX = (isFlipped ? 7 - fromFile : fromFile) - 3.5;
    final startY = (isFlipped ? fromRank : 7 - fromRank) - 3.5;
    final targetX = (isFlipped ? 7 - toFile : toFile) - 3.5;
    final targetY = (isFlipped ? toRank : 7 - toRank) - 3.5;

    // Linear interpolation on ground plane
    final currentX = startX + (targetX - startX) * progress;
    final currentY = startY + (targetY - startY) * progress;

    // Parabolic arc elevation peak
    final elevation = math.sin(progress * math.pi) * 0.85;

    return (dx: currentX, dy: currentY, elevation: elevation);
  }
}

/// Coordinates and drives 3D piece move and capture animations.
class MoveAnimationController extends ChangeNotifier {
  Active3DMoveAnimation? activeAnimation;
  AnimationController? _tickerController;

  void attachTicker(AnimationController controller) {
    _tickerController = controller;
    _tickerController?.addListener(() {
      if (activeAnimation != null && _tickerController != null) {
        activeAnimation = Active3DMoveAnimation(
          pieceChar: activeAnimation!.pieceChar,
          fromSquare: activeAnimation!.fromSquare,
          toSquare: activeAnimation!.toSquare,
          capturedPiece: activeAnimation!.capturedPiece,
          progress: _tickerController!.value,
        );
        notifyListeners();
      }
    });

    _tickerController?.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        activeAnimation = null;
        notifyListeners();
      }
    });
  }

  /// Triggers a 3D parabolic move animation.
  void startMoveAnimation({
    required String pieceChar,
    required String fromSquare,
    required String toSquare,
    String? capturedPiece,
  }) {
    activeAnimation = Active3DMoveAnimation(
      pieceChar: pieceChar,
      fromSquare: fromSquare,
      toSquare: toSquare,
      capturedPiece: capturedPiece,
      progress: 0.0,
    );
    _tickerController?.forward(from: 0.0);
    notifyListeners();
  }
}
