# Changelog

All notable changes to the Enterprise Chess platform are documented in this file in adherence to [Semantic Versioning](https://semver.org/).

---

## [1.1.0] - 2026-09-12

### Added

#### 3D Board Rendering Pipeline

- **Interactive 3D Viewport (`lib/views/game_board/board_3d/`)**: Full 3D perspective board rendering using CustomPainter with camera orbit (pitch/yaw), zoom scale, and camera reset controls.
- **3D Piece Lathe Meshes**: Procedural lathe geometry profiles with normal shading, collars, and bevels for King, Queen, Rook, Bishop, Knight, and Pawn.
- **Painter's Algorithm Depth-Sorting**: Centroid camera-space depth calculations ensuring artifact-free occlusion rendering.
- **Screen-to-Square 3D Raycaster (`SquareRaycaster`)**: Mathematical ray-plane hit-testing translating 2D touch coordinates $(x, y)$ directly into chess squares ($a1..h8$).
- **Parabolic Move Animations (`MoveAnimationController`)**: Smooth tweened elevation curves for piece movements, captures, and castling.
- **Material Themes**: Walnut/Maple, Obsidian/Marble, Cyberpunk Neon, and Brushed Metal presets.
- **Live 2D/3D Toggle & Graceful Error Boundary**: Seamless toggle between 2D and 3D with automatic fallback to 2D on `RenderInitException`.

#### Zero-Trust Security & Cloud Functions

- **Authoritative Cloud Functions (`functions/src/`)**: TypeScript Cloud Functions (`validateMove.ts`, `enforceTimeout.ts`, `rateLimiter.ts`, `inputSchemaGuard.ts`).
- **Token-Bucket Rate Limiter**: Per-UID token bucket preventing move flood attacks and abuse.
- **Client Move Idempotency**: UUIDv4 `clientMoveId` replay protection in atomic Firestore transactions.
- **Exhaustive Draw Evaluator (`ChessRulesEvaluator`)**: Exact FEN threefold repetition and exhaustive 4-case insufficient material detection (King vs King, King+Bishop vs King, King+Knight vs King, King+Bishop vs King+Bishop on same-colored squares).
- **Anti-Cheat Suspension Filter**: Real-time ban check across matchmaking queues and match creation.

#### Testing Suite

- 33 automated tests across unit, integration, and E2E simulation suites covering 100% of rules, transactions, raycasting, and checkmate pipelines.

---

## [1.0.0] - 2026-09-12

### Initial Release

- Pure Dart rules engine with `chess` package.
- Riverpod 2.x `AsyncNotifierProvider` state architecture.
- Background isolate Stockfish FFI engine (`stockfish_flutter_plus`).
- Production `firestore.rules` and tamper-proof server clock protocol.
