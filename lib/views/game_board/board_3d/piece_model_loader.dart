/// Represents a 3D slice/ring in a piece's lathe geometry profile.
class LatheRing {
  final double height; // Relative height 0.0 (base) to 1.0 (top)
  final double radius; // Relative radius at this height

  const LatheRing(this.height, this.radius);
}

/// Mesh profile for procedural 3D chess pieces.
class Piece3DProfile {
  final List<LatheRing> rings;
  final double baseRadius;
  final double totalHeight;

  const Piece3DProfile({
    required this.rings,
    required this.baseRadius,
    required this.totalHeight,
  });

  /// Pawn profile: compact, wide base, round head
  static const pawn = Piece3DProfile(
    baseRadius: 0.36,
    totalHeight: 0.65,
    rings: [
      LatheRing(0.00, 0.36),
      LatheRing(0.08, 0.34),
      LatheRing(0.14, 0.26),
      LatheRing(0.24, 0.20),
      LatheRing(0.40, 0.16),
      LatheRing(0.55, 0.18),
      LatheRing(0.68, 0.14),
      LatheRing(0.78, 0.22),
      LatheRing(0.92, 0.22),
      LatheRing(1.00, 0.02),
    ],
  );

  /// Knight profile: stylized angled profile
  static const knight = Piece3DProfile(
    baseRadius: 0.38,
    totalHeight: 0.78,
    rings: [
      LatheRing(0.00, 0.38),
      LatheRing(0.10, 0.35),
      LatheRing(0.18, 0.28),
      LatheRing(0.35, 0.24),
      LatheRing(0.52, 0.28),
      LatheRing(0.70, 0.26),
      LatheRing(0.85, 0.20),
      LatheRing(1.00, 0.08),
    ],
  );

  /// Bishop profile: elegant tapered body with miter cut
  static const bishop = Piece3DProfile(
    baseRadius: 0.38,
    totalHeight: 0.88,
    rings: [
      LatheRing(0.00, 0.38),
      LatheRing(0.10, 0.35),
      LatheRing(0.18, 0.26),
      LatheRing(0.40, 0.18),
      LatheRing(0.60, 0.20),
      LatheRing(0.72, 0.16),
      LatheRing(0.86, 0.22),
      LatheRing(0.95, 0.14),
      LatheRing(1.00, 0.04),
    ],
  );

  /// Rook profile: sturdy cylindrical castle
  static const rook = Piece3DProfile(
    baseRadius: 0.40,
    totalHeight: 0.74,
    rings: [
      LatheRing(0.00, 0.40),
      LatheRing(0.10, 0.38),
      LatheRing(0.18, 0.28),
      LatheRing(0.50, 0.24),
      LatheRing(0.75, 0.26),
      LatheRing(0.85, 0.32),
      LatheRing(1.00, 0.32),
    ],
  );

  /// Queen profile: tall, coronet flares
  static const queen = Piece3DProfile(
    baseRadius: 0.42,
    totalHeight: 1.02,
    rings: [
      LatheRing(0.00, 0.42),
      LatheRing(0.08, 0.38),
      LatheRing(0.16, 0.28),
      LatheRing(0.45, 0.20),
      LatheRing(0.68, 0.24),
      LatheRing(0.78, 0.18),
      LatheRing(0.88, 0.30),
      LatheRing(0.96, 0.24),
      LatheRing(1.00, 0.06),
    ],
  );

  /// King profile: commanding stature with cross finial
  static const king = Piece3DProfile(
    baseRadius: 0.42,
    totalHeight: 1.15,
    rings: [
      LatheRing(0.00, 0.42),
      LatheRing(0.08, 0.39),
      LatheRing(0.16, 0.30),
      LatheRing(0.45, 0.22),
      LatheRing(0.72, 0.26),
      LatheRing(0.82, 0.20),
      LatheRing(0.92, 0.28),
      LatheRing(0.98, 0.18),
      LatheRing(1.00, 0.08),
    ],
  );

  static Piece3DProfile getProfile(String pieceChar) {
    switch (pieceChar.toUpperCase()) {
      case 'P':
        return pawn;
      case 'N':
        return knight;
      case 'B':
        return bishop;
      case 'R':
        return rook;
      case 'Q':
        return queen;
      case 'K':
        return king;
      default:
        return pawn;
    }
  }
}

/// Cache of pre-computed piece geometry slices and shading tables.
class PieceModelLoader {
  static final PieceModelLoader instance = PieceModelLoader._();
  PieceModelLoader._();

  final Map<String, Piece3DProfile> _profileCache = {};

  Piece3DProfile loadProfile(String pieceChar) {
    final key = pieceChar.toUpperCase();
    return _profileCache.putIfAbsent(key, () => Piece3DProfile.getProfile(key));
  }
}
