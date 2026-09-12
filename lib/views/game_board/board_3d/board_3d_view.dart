import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chess/chess.dart' as chess_lib;
import 'chess_scene_controller.dart';
import 'piece_model_loader.dart';
import 'square_raycaster.dart';
import 'move_animation_controller.dart';

/// 3D Chess Board View widget providing full perspective rendering, orbit/zoom controls, and tap-to-move interaction.
class Board3DView extends StatefulWidget {
  final String fen;
  final String? selectedSquare;
  final List<String> legalDestinations;
  final String? lastMoveFrom;
  final String? lastMoveTo;
  final String? kingInCheckSquare;
  final bool isFlipped;
  final void Function(String square) onSquareTap;
  final ChessSceneController sceneController;
  final MoveAnimationController? animationController;
  final VoidCallback? onFallbackTo2D;

  const Board3DView({
    super.key,
    required this.fen,
    this.selectedSquare,
    this.legalDestinations = const [],
    this.lastMoveFrom,
    this.lastMoveTo,
    this.kingInCheckSquare,
    this.isFlipped = false,
    required this.onSquareTap,
    required this.sceneController,
    this.animationController,
    this.onFallbackTo2D,
  });

  @override
  State<Board3DView> createState() => _Board3DViewState();
}

class _Board3DViewState extends State<Board3DView>
    with SingleTickerProviderStateMixin {
  late AnimationController _moveAnimController;
  Offset? _lastPanPoint;
  double _baseScale = 1.0;

  @override
  void initState() {
    super.initState();
    _moveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    widget.animationController?.attachTicker(_moveAnimController);
  }

  @override
  void dispose() {
    _moveAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.sceneController,
        if (widget.animationController != null) widget.animationController!,
      ]),
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);

            return GestureDetector(
              onScaleStart: (details) {
                _lastPanPoint = details.focalPoint;
                _baseScale = widget.sceneController.zoom;
              },
              onScaleUpdate: (details) {
                if (details.pointerCount == 1 && _lastPanPoint != null) {
                  final dx = details.focalPoint.dx - _lastPanPoint!.dx;
                  final dy = details.focalPoint.dy - _lastPanPoint!.dy;
                  _lastPanPoint = details.focalPoint;

                  // Pan gestures drive 3D orbit pitch and yaw
                  final deltaYaw = dx * 0.008;
                  final deltaPitch = dy * 0.006;
                  widget.sceneController.updateOrbit(deltaPitch, deltaYaw);
                } else if (details.pointerCount >= 2) {
                  // Pinch-to-zoom
                  final newZoom = _baseScale * details.scale;
                  widget.sceneController.setZoom(newZoom);
                }
              },
              onScaleEnd: (_) {
                _lastPanPoint = null;
              },
              onTapUp: (details) {
                final tappedSquare = SquareRaycaster.raycast(
                  details.localPosition,
                  size,
                  pitch: widget.sceneController.pitch,
                  yaw: widget.sceneController.yaw,
                  zoom: widget.sceneController.zoom,
                  isFlipped: widget.sceneController.isFlipped,
                );

                if (tappedSquare != null) {
                  HapticFeedback.selectionClick();
                  widget.onSquareTap(tappedSquare);
                }
              },
              onDoubleTap: () {
                widget.sceneController.resetCamera();
              },
              child: Stack(
                children: [
                  CustomPaint(
                    size: size,
                    painter: _ChessBoard3DPainter(
                      fen: widget.fen,
                      selectedSquare: widget.selectedSquare,
                      legalDestinations: widget.legalDestinations,
                      lastMoveFrom: widget.lastMoveFrom,
                      lastMoveTo: widget.lastMoveTo,
                      kingInCheckSquare: widget.kingInCheckSquare,
                      sceneController: widget.sceneController,
                      activeMoveAnimation:
                          widget.animationController?.activeAnimation,
                    ),
                  ),
                  // Floating camera controls overlay
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildControlButton(
                          icon: Icons.refresh_rounded,
                          tooltip: 'Reset Camera',
                          onTap: () => widget.sceneController.resetCamera(),
                        ),
                        const SizedBox(width: 8),
                        _buildControlButton(
                          icon: Icons.threed_rotation_rounded,
                          tooltip: 'Flip Perspective',
                          onTap: () =>
                              widget.sceneController.toggleOrientation(),
                        ),
                        if (widget.onFallbackTo2D != null) ...[
                          const SizedBox(width: 8),
                          _buildControlButton(
                            icon: Icons.grid_view_rounded,
                            tooltip: 'Switch to 2D',
                            onTap: widget.onFallbackTo2D!,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xCC1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x33FFFFFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white70, size: 20),
        tooltip: tooltip,
        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
        padding: EdgeInsets.zero,
        onPressed: onTap,
      ),
    );
  }
}

/// CustomPainter delivering 3D perspective projection, Z-sorted depth rendering, and dynamic piece geometry.
class _ChessBoard3DPainter extends CustomPainter {
  final String fen;
  final String? selectedSquare;
  final List<String> legalDestinations;
  final String? lastMoveFrom;
  final String? lastMoveTo;
  final String? kingInCheckSquare;
  final ChessSceneController sceneController;
  final Active3DMoveAnimation? activeMoveAnimation;

  _ChessBoard3DPainter({
    required this.fen,
    this.selectedSquare,
    this.legalDestinations = const [],
    this.lastMoveFrom,
    this.lastMoveTo,
    this.kingInCheckSquare,
    required this.sceneController,
    this.activeMoveAnimation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final scale = (size.width * 0.42 * sceneController.zoom);

    final pitch = sceneController.pitch;
    final effectiveYaw = sceneController.isFlipped
        ? sceneController.yaw - math.pi
        : sceneController.yaw;
    final material = sceneController.material;

    final cosP = math.cos(pitch);
    final sinP = math.sin(pitch);
    final cosY = math.cos(effectiveYaw);
    final sinY = math.sin(effectiveYaw);

    // 3D Point Projection helper: (x, y, z) in board space -> (screenX, screenY, depth)
    ({double sx, double sy, double depth}) project(double x, double y, double z) {
      // 1. Rotate by Yaw in XY ground plane
      final rx = x * cosY - y * sinY;
      final ry = x * sinY + y * cosY;

      // 2. Rotate by Pitch in YZ plane
      final py = ry * cosP - z * sinP;
      final pz = ry * sinP + z * cosP;

      // 3. Screen mapping with perspective depth
      final depthFactor = 1.0 / (1.0 - (pz * 0.08));
      final sx = centerX + (rx * scale * depthFactor);
      final sy = centerY + (py * scale * depthFactor);
      return (sx: sx, sy: sy, depth: pz);
    }

    // 1. Draw 3D Board Base / Bevel
    final bevelPaint = Paint()
      ..color = material.boardBevelColor
      ..style = PaintingStyle.fill;

    final bevelBorderPaint = Paint()
      ..color = material.boardBevelColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Draw board foundation slab
    const boardMargin = 4.35;
    const slabDepth = -0.45;
    final p0 = project(-boardMargin, -boardMargin, slabDepth);
    final p1 = project(boardMargin, -boardMargin, slabDepth);
    final p2 = project(boardMargin, boardMargin, slabDepth);
    final p3 = project(-boardMargin, boardMargin, slabDepth);

    final slabPath = Path()
      ..moveTo(p0.sx, p0.sy)
      ..lineTo(p1.sx, p1.sy)
      ..lineTo(p2.sx, p2.sy)
      ..lineTo(p3.sx, p3.sy)
      ..close();
    canvas.drawPath(slabPath, bevelPaint);
    canvas.drawPath(slabPath, bevelBorderPaint);

    // 2. Draw 64 Squares on Board Surface
    final lightSquarePaint = Paint()..color = material.lightSquareColor;
    final darkSquarePaint = Paint()..color = material.darkSquareColor;
    final selectPaint = Paint()..color = const Color(0xB3EAB308);
    final destPaint = Paint()..color = const Color(0x8038BDF8);
    final checkPaint = Paint()..color = const Color(0xB3EF4444);
    final lastMovePaint = Paint()..color = const Color(0x66FBBF24);

    for (int rank = 0; rank < 8; rank++) {
      for (int file = 0; file < 8; file++) {
        final actualFile =
            sceneController.isFlipped ? 7 - file : file;
        final actualRank =
            sceneController.isFlipped ? rank : 7 - rank;
        final sqName =
            '${String.fromCharCode('a'.codeUnitAt(0) + actualFile)}${actualRank + 1}';

        final bx = file - 4.0;
        final by = rank - 4.0;

        final sq0 = project(bx, by, 0.0);
        final sq1 = project(bx + 1.0, by, 0.0);
        final sq2 = project(bx + 1.0, by + 1.0, 0.0);
        final sq3 = project(bx, by + 1.0, 0.0);

        final sqPath = Path()
          ..moveTo(sq0.sx, sq0.sy)
          ..lineTo(sq1.sx, sq1.sy)
          ..lineTo(sq2.sx, sq2.sy)
          ..lineTo(sq3.sx, sq3.sy)
          ..close();

        final isLight = (actualFile + actualRank) % 2 != 0;
        canvas.drawPath(sqPath, isLight ? lightSquarePaint : darkSquarePaint);

        // Highlight overlays
        if (sqName == selectedSquare) {
          canvas.drawPath(sqPath, selectPaint);
        } else if (sqName == kingInCheckSquare) {
          canvas.drawPath(sqPath, checkPaint);
        } else if (sqName == lastMoveFrom || sqName == lastMoveTo) {
          canvas.drawPath(sqPath, lastMovePaint);
        } else if (legalDestinations.contains(sqName)) {
          // Destination indicator disc
          final sqCenter = project(bx + 0.5, by + 0.5, 0.02);
          final discRadius = (scale * 0.18);
          canvas.drawCircle(
            Offset(sqCenter.sx, sqCenter.sy),
            discRadius,
            destPaint,
          );
        }
      }
    }

    // 3. Render 3D Pieces with Depth-Sorting (Painter's Algorithm)
    final chess = chess_lib.Chess.fromFEN(fen);
    final renderItems = <_PieceRenderItem>[];

    for (int rank = 0; rank < 8; rank++) {
      for (int file = 0; file < 8; file++) {
        final actualFile =
            sceneController.isFlipped ? 7 - file : file;
        final actualRank =
            sceneController.isFlipped ? rank : 7 - rank;
        final sq =
            '${String.fromCharCode('a'.codeUnitAt(0) + actualFile)}${actualRank + 1}';

        // Check if piece is currently being animated
        if (activeMoveAnimation != null &&
            activeMoveAnimation!.fromSquare == sq) {
          continue; // Drawn separately in animated position
        }

        final piece = chess.get(sq);
        if (piece != null) {
          final isWhite = piece.color == chess_lib.Color.WHITE;
          final pieceChar = isWhite
              ? piece.type.name.toUpperCase()
              : piece.type.name.toLowerCase();

          final bx = file - 3.5;
          final by = rank - 3.5;
          final proj = project(bx, by, 0.0);

          renderItems.add(_PieceRenderItem(
            pieceChar: pieceChar,
            x: bx,
            y: by,
            elevation: 0.0,
            depth: proj.depth,
            isWhite: isWhite,
          ));
        }
      }
    }

    // Include moving piece animation item
    if (activeMoveAnimation != null) {
      final animPos = activeMoveAnimation!.computeInterpolatedPosition(
        isFlipped: sceneController.isFlipped,
      );
      final proj = project(animPos.dx, animPos.dy, animPos.elevation);
      final isWhite = activeMoveAnimation!.pieceChar ==
          activeMoveAnimation!.pieceChar.toUpperCase();

      renderItems.add(_PieceRenderItem(
        pieceChar: activeMoveAnimation!.pieceChar,
        x: animPos.dx,
        y: animPos.dy,
        elevation: animPos.elevation,
        depth: proj.depth,
        isWhite: isWhite,
      ));
    }

    // Sort items by depth (farthest from camera rendered first)
    renderItems.sort((a, b) => b.depth.compareTo(a.depth));

    // Draw pieces
    for (final item in renderItems) {
      _drawPiece3D(
        canvas: canvas,
        project: project,
        item: item,
        scale: scale,
        material: material,
      );
    }
  }

  /// Draws a single piece in 3D using stacked lathe profile rings and directional shading.
  void _drawPiece3D({
    required Canvas canvas,
    required ({double sx, double sy, double depth}) Function(
            double x, double y, double z)
        project,
    required _PieceRenderItem item,
    required double scale,
    required Board3DMaterial material,
  }) {
    final profile = PieceModelLoader.instance.loadProfile(item.pieceChar);

    // Drop shadow on ground plane
    final shadowProj = project(item.x + 0.12, item.y + 0.12, 0.0);
    final shadowPaint = Paint()
      ..color = const Color(0x55000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(shadowProj.sx, shadowProj.sy),
        width: profile.baseRadius * scale * 0.9,
        height: profile.baseRadius * scale * 0.55,
      ),
      shadowPaint,
    );

    // Draw stacked lathe rings with Phong-like gradient shading
    for (int i = 0; i < profile.rings.length - 1; i++) {
      final r0 = profile.rings[i];
      final r1 = profile.rings[i + 1];

      final z0 = (r0.height * profile.totalHeight) + item.elevation;
      final z1 = (r1.height * profile.totalHeight) + item.elevation;

      final p0 = project(item.x, item.y, z0);
      final p1 = project(item.x, item.y, z1);

      final ringRadius0 = r0.radius * scale * 0.52;
      final ringRadius1 = r1.radius * scale * 0.52;

      // Lighting normal simulation (ambient + directional key light)
      final lightIntensity = ((1.0 - (r0.height * 0.35))).clamp(0.65, 1.15);
      final rVal = ((item.isWhite ? material.whitePieceColor.r : material.blackPieceColor.r) * 255.0 * lightIntensity).round().clamp(0, 255);
      final gVal = ((item.isWhite ? material.whitePieceColor.g : material.blackPieceColor.g) * 255.0 * lightIntensity).round().clamp(0, 255);
      final bVal = ((item.isWhite ? material.whitePieceColor.b : material.blackPieceColor.b) * 255.0 * lightIntensity).round().clamp(0, 255);
      final shadedColor = Color.fromARGB(255, rVal, gVal, bVal);

      final ringPaint = Paint()..color = shadedColor;
      final strokePaint = Paint()
        ..color = (item.isWhite ? const Color(0x33000000) : const Color(0x33FFFFFF))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      final path = Path()
        ..moveTo(p0.sx - ringRadius0, p0.sy)
        ..lineTo(p1.sx - ringRadius1, p1.sy)
        ..lineTo(p1.sx + ringRadius1, p1.sy)
        ..lineTo(p0.sx + ringRadius0, p0.sy)
        ..close();

      canvas.drawPath(path, ringPaint);
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChessBoard3DPainter oldDelegate) {
    return oldDelegate.fen != fen ||
        oldDelegate.selectedSquare != selectedSquare ||
        oldDelegate.legalDestinations != legalDestinations ||
        oldDelegate.lastMoveFrom != lastMoveFrom ||
        oldDelegate.lastMoveTo != lastMoveTo ||
        oldDelegate.kingInCheckSquare != kingInCheckSquare ||
        oldDelegate.activeMoveAnimation != activeMoveAnimation;
  }
}

class _PieceRenderItem {
  final String pieceChar;
  final double x;
  final double y;
  final double elevation;
  final double depth;
  final bool isWhite;

  const _PieceRenderItem({
    required this.pieceChar,
    required this.x,
    required this.y,
    required this.elevation,
    required this.depth,
    required this.isWhite,
  });
}
