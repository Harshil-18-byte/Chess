import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Preset themes for 3D board materials and lighting.
enum BoardTheme3DPreset {
  walnutMaple,
  obsidianMarble,
  cyberpunkNeon,
  brushedMetal,
}

/// Material properties for 3D board rendering.
class Board3DMaterial {
  final Color lightSquareColor;
  final Color darkSquareColor;
  final Color whitePieceColor;
  final Color blackPieceColor;
  final Color boardBevelColor;
  final Color ambientLightColor;
  final double specularShininess;

  const Board3DMaterial({
    required this.lightSquareColor,
    required this.darkSquareColor,
    required this.whitePieceColor,
    required this.blackPieceColor,
    required this.boardBevelColor,
    required this.ambientLightColor,
    this.specularShininess = 32.0,
  });

  static const walnutMaple = Board3DMaterial(
    lightSquareColor: Color(0xFFF0D9B5),
    darkSquareColor: Color(0xFFB58863),
    whitePieceColor: Color(0xFFFAF0E6),
    blackPieceColor: Color(0xFF2C2420),
    boardBevelColor: Color(0xFF5C3A21),
    ambientLightColor: Color(0xFFFFFFFF),
    specularShininess: 24.0,
  );

  static const obsidianMarble = Board3DMaterial(
    lightSquareColor: Color(0xFFECEFF1),
    darkSquareColor: Color(0xFF37474F),
    whitePieceColor: Color(0xFFFFFFFF),
    blackPieceColor: Color(0xFF1A1A1A),
    boardBevelColor: Color(0xFF263238),
    ambientLightColor: Color(0xFFE2E8F0),
    specularShininess: 64.0,
  );

  static const cyberpunkNeon = Board3DMaterial(
    lightSquareColor: Color(0xFF0F172A),
    darkSquareColor: Color(0xFF1E293B),
    whitePieceColor: Color(0xFF38BDF8),
    blackPieceColor: Color(0xFFF43F5E),
    boardBevelColor: Color(0xFF0B0F19),
    ambientLightColor: Color(0xFF6366F1),
    specularShininess: 128.0,
  );

  static const brushedMetal = Board3DMaterial(
    lightSquareColor: Color(0xFFCBD5E1),
    darkSquareColor: Color(0xFF64748B),
    whitePieceColor: Color(0xFFF8FAFC),
    blackPieceColor: Color(0xFF334155),
    boardBevelColor: Color(0xFF1E293B),
    ambientLightColor: Color(0xFFFFFFFF),
    specularShininess: 80.0,
  );

  static Board3DMaterial getPreset(BoardTheme3DPreset preset) {
    switch (preset) {
      case BoardTheme3DPreset.walnutMaple:
        return walnutMaple;
      case BoardTheme3DPreset.obsidianMarble:
        return obsidianMarble;
      case BoardTheme3DPreset.cyberpunkNeon:
        return cyberpunkNeon;
      case BoardTheme3DPreset.brushedMetal:
        return brushedMetal;
    }
  }
}

/// Controls the 3D viewport camera, orbit angles, zoom, and perspective transformation.
class ChessSceneController extends ChangeNotifier {
  double pitch; // Vertical orbit angle in radians (e.g. 0.6 - 1.2)
  double yaw; // Horizontal orbit angle in radians
  double zoom; // Camera distance scale (0.7 - 1.5)
  bool isFlipped; // True if viewing from Black's perspective
  BoardTheme3DPreset themePreset;

  ChessSceneController({
    this.pitch = 0.85,
    this.yaw = 0.0,
    this.zoom = 1.0,
    this.isFlipped = false,
    this.themePreset = BoardTheme3DPreset.walnutMaple,
  });

  Board3DMaterial get material => Board3DMaterial.getPreset(themePreset);

  /// Updates orbit angles through user drag gestures.
  void updateOrbit(double deltaPitch, double deltaYaw) {
    pitch = (pitch + deltaPitch).clamp(0.45, 1.40);
    yaw = (yaw + deltaYaw) % (2 * math.pi);
    notifyListeners();
  }

  /// Updates zoom scale through pinch/wheel gestures.
  void updateZoom(double scaleFactor) {
    zoom = (zoom * scaleFactor).clamp(0.65, 1.60);
    notifyListeners();
  }

  /// Explicitly sets zoom level.
  void setZoom(double newZoom) {
    zoom = newZoom.clamp(0.65, 1.60);
    notifyListeners();
  }

  /// Resets camera to default perspective for the current orientation.
  void resetCamera() {
    pitch = 0.85;
    yaw = isFlipped ? math.pi : 0.0;
    zoom = 1.0;
    notifyListeners();
  }

  /// Toggles board orientation (White vs Black).
  void toggleOrientation() {
    isFlipped = !isFlipped;
    yaw = isFlipped ? math.pi : 0.0;
    notifyListeners();
  }

  /// Sets active 3D theme preset.
  void setTheme(BoardTheme3DPreset preset) {
    themePreset = preset;
    notifyListeners();
  }
}
