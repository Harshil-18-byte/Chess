import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Screen-to-3D chess square raycasting engine.
class SquareRaycaster {
  /// Converts a screen touch offset into a board square (e.g. 'e4') or null if out-of-bounds.
  static String? raycast(
    Offset touchPoint,
    Size viewportSize, {
    required double pitch,
    required double yaw,
    required double zoom,
    required bool isFlipped,
  }) {
    final centerX = viewportSize.width / 2;
    final centerY = viewportSize.height / 2;

    // Centered screen coordinate
    final dx = (touchPoint.dx - centerX) / (viewportSize.width * 0.45 * zoom);
    final dy = (touchPoint.dy - centerY) / (viewportSize.height * 0.45 * zoom);

    // Apply inverse perspective projection:
    // Screen (dx, dy) represents 3D plane rotated by pitch around X and yaw around Z
    // In camera space:
    // x_cam = dx
    // y_cam = dy / sin(pitch)
    // Board space rotation by yaw:
    final cosP = math.cos(pitch);
    final sinP = math.sin(pitch);
    if (sinP.abs() < 0.01) return null;

    // Projected ground plane coordinates (-4.0 to +4.0 relative to center)
    final groundY = dy / sinP;
    final groundX = dx + (groundY * cosP * 0.15); // Adjust for perspective tilt

    // Rotate ground coordinates by yaw to get unrotated board square
    final effectiveYaw = isFlipped ? yaw - math.pi : yaw;
    final cosY = math.cos(-effectiveYaw);
    final sinY = math.sin(-effectiveYaw);

    final rotatedX = groundX * cosY - groundY * sinY;
    final rotatedY = groundX * sinY + groundY * cosY;

    // Board spans -4.0 to +4.0 across 8 squares (each square is 1.0 unit wide)
    final fileIndex = ((rotatedX + 4.0)).floor();
    final rankIndex = ((rotatedY + 4.0)).floor();

    if (fileIndex < 0 || fileIndex > 7 || rankIndex < 0 || rankIndex > 7) {
      return null;
    }

    final actualFile = isFlipped ? 7 - fileIndex : fileIndex;
    final actualRank = isFlipped ? rankIndex : 7 - rankIndex;

    if (actualFile < 0 || actualFile > 7 || actualRank < 0 || actualRank > 7) {
      return null;
    }

    final fileChar = String.fromCharCode('a'.codeUnitAt(0) + actualFile);
    final rankNum = actualRank + 1;
    return '$fileChar$rankNum';
  }
}
