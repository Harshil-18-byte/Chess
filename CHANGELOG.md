# Chessical // Changelog Specification

All notable changes, architectural milestones, engine integrations, security enhancements, and rendering upgrades for the Chessical platform are documented in this file in strict adherence to [Semantic Versioning (SemVer 2.0.0)](https://semver.org/).

---

## Release History Matrix

| Version | Release Date | Key Milestone | Core Deliverable |
| :--- | :--- | :--- | :--- |
| **v1.2.0** | 2026-09-12 | Obsidian Magma Branding & Documentation Hardening | Complete CuraVeris-aligned architecture guides, brand logo integration, and UUIDv4 schema validation. |
| **v1.1.0** | 2026-09-12 | 3D Viewport & Raycasting Engine | Perspective CustomPainter 3D board, procedural lathe mesh profiles, screen-to-square raycaster, and 2D fallback. |
| **v1.0.0** | 2026-09-12 | Zero-Exploit Core & Cloud Synchronization | Pure-Dart rules engine, Riverpod AsyncNotifier state machine, Stockfish FFI isolate, and atomic Firestore transactions. |

---

## [1.2.0] - 2026-09-12

### Added
- **Chessical Obsidian & Magma Brand Identity**:
  - Fractured obsidian King and Queen logo asset (`assets/images/logo.png`).
  - High-contrast brand design tokens (`brandEmber` `#FF6B00`, `brandMagma` `#FF8A00`, `brandFlame` `#FF4500`, `brandGlow` `#FFB03B`, `scaffoldBackground` `#0C0F17`).
  - Hero branding section in `HomeScreen` with glowing magma gradient borders.
- **Architectural Documentation Suite**:
  - CuraVeris-aligned technical specifications across [README.md](./README.md), [ARCHITECTURE.md](./ARCHITECTURE.md), and [SECURITY.md](./SECURITY.md).
  - Mathematical derivations for 3D camera Euler transformations, normalized device raycasting, and FIDE 4-case insufficient material piecewise functions.
- **Enhanced Cloud Functions Schema Validation**:
  - Strict regex UUIDv4 validation (`UUID_REGEX`) in `inputSchemaGuard.ts` for all `clientMoveId` fields.

---

## [1.1.0] - 2026-09-12

### Added
- **3D Real-Time Board & Piece Pipeline (`lib/views/game_board/board_3d/`)**:
  - CustomPainter-based perspective 3D canvas with orbital pitch ($\theta$), yaw ($\phi$), and pinch-zoom controls (`ChessSceneController`).
  - Procedural 3D piece lathe geometry loader (`PieceModelLoader`) with normal shading and in-memory profile caching.
  - Screen-to-3D-square raycaster (`SquareRaycaster`) computing inverse ray-plane intersection directly to algebraic coordinates.
  - Parabolic tweened move animations (`MoveAnimationController`) with distinct trajectories for normal moves, captures, castling, and promotions.
- **Graceful Error Boundary & 2D Fallback**:
  - Live 2D/3D toggle button in `GameBoardView`.
  - Automatic fallback from 3D to 2D canvas on `RenderInitException` or GPU context failure.

---

## [1.0.0] - 2026-09-12

### Added
- **Deterministic Pure-Dart Game Engine (`lib/core/rules/chess_rules_evaluator.dart`)**:
  - Zero-LLM move calculation, check, checkmate, stalemate, and 50-move rule evaluation.
  - Exhaustive 4-case insufficient material evaluator ($K\text{ vs }K$, $K+B\text{ vs }K$, $K+N\text{ vs }K$, $K+B\text{ vs }K+B$ on same-colored squares).
  - Exact FEN position history tracking for threefold repetition detection.
- **Riverpod Reactive State Architecture (`lib/state/game_state_notifier.dart`)**:
  - Immutable `AsyncNotifier<ChessMatch>` state machine.
  - Cryptographic UUIDv4 `clientMoveId` generation and in-flight action locking.
  - Exponential backoff stream reconnection.
- **On-Device Stockfish FFI Service (`lib/services/stockfish_service.dart`)**:
  - Native C++ Stockfish engine isolate wrapper using `stockfish_flutter_plus`.
  - Singleton concurrency management and zero-allocation UI frame loop.
- **Zero-Trust Backend & Security (`functions/src/` & `firestore.rules`)**:
  - Production Firestore security rules enforcing turn matching, server timestamp equality, and immutable create-only move logs.
  - Cloud Functions: `validateMove.ts` (authoritative re-check), `enforceTimeout.ts` (Pub/Sub timeout sweeper), and `rateLimiter.ts` (token-bucket limiter).
