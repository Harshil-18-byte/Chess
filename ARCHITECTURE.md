# Enterprise Chess — Architectural Specification

This document details the architectural decisions, cryptographic constraints, data synchronization flows, and isolation boundaries of the Enterprise Chess application.

---

## 1. Step-by-Step Data Mutation Flow for a Move

```text
[User Drag / Tap Event (2D Grid or 3D Raycaster)]
        │
        ▼
[GameBoardView._processMoveAttempt()]
        │
        ├─► Local UI verification (piece ownership, turn match)
        ├─► If Pawn on promotion rank: prompt UI dialog for promotion piece
        │
        ▼
[GameStateNotifier.executeMove(from, to, promotion)]
        │
        ├─► Step 1: Generate Client Move UUID (Uuid.v4 clientMoveId)
        │
        ├─► Step 2: In-Memory Pure Dart Validation via chess package:
        │     - Load current FEN into chess.Chess.fromFEN(currentFen)
        │     - Execute chess.move({'from': from, 'to': to, 'promotion': promotion})
        │     - If illegal: throw IllegalMoveException (reject before network trip)
        │
        ├─► Step 3: Compute Position Deltas & Terminal Rules:
        │     - Derive new FEN string
        │     - Generate SAN (Standard Algebraic Notation) notation (e.g. "Nf3", "Qxf7#")
        │     - Evaluate terminal flags: in_checkmate, in_stalemate, in_threefold_repetition,
        │       50-move rule, exhaustive 4-case insufficient_material
        │
        ├─► Step 4: Dispatch Atomic Firestore Transaction / Cloud Function:
        │     - Acquire lock on /matches/{matchId}
        │     - Re-read match document inside transaction
        │     - Assert match is active
        │     - Assert clientMoveId not in processedClientMoveIds (Idempotency)
        │     - Verify caller UID matches registered player color for activeTurn
        │     - Compute elapsed time: serverNow - lastMoveServerTimestamp
        │     - Deduct elapsed time from active player's remaining clock
        │     - Flip activeTurn ('w' <-> 'b')
        │     - Append clientMoveId to processedClientMoveIds
        │     - Append newFen to positionHistory
        │     - Write updated match document with lastMoveServerTimestamp: FieldValue.serverTimestamp()
        │     - Write new document in /matches/{matchId}/moves/{moveNumber} (immutable log)
        │
        ▼
[Firestore Snapshot Emission]
        │
        ├─► All subscribed clients receive authoritative snapshot
        ├─► Riverpod GameStateNotifier updates state = AsyncData(updatedMatch)
        ├─► GameClockWidget corrects local visual drift to authoritative remaining time
        └─► If single-player vs engine & it is Black's turn: trigger background Stockfish evaluation
```

---

## 2. Transaction Boundaries & Security Isolations

### Inside the Transaction (Atomic & Guarded)

1. **Match document re-read & participant validation**: Prevents race conditions and desynchronized dual-submissions.
2. **Idempotency Guard**: Validates `clientMoveId` against `processedClientMoveIds` array to block duplicate submissions.
3. **Server clock delta deduction**: `whiteMillisRemaining` or `blackMillisRemaining` adjusted based on server timestamp deltas.
4. **Turn flip & FEN update**: Updates `currentFen`, `activeTurn`, `status`, `lastMoveSan`, `positionHistory`.
5. **Append to `moves` subcollection**: Creates immutable historical record with move number, SAN, and post-move FEN.

### Outside the Transaction (Local / Non-Blocking)

1. **Dart engine move legality test**: Avoids network overhead for illegal moves.
2. **UI micro-animation & 100ms clock ticker**: Provides 60fps countdown visuals without server polling.
3. **Stockfish FFI computation**: Runs in an isolated background thread without network calls.

---

## 3. Tamper-Proof Clock Protocol

### The Problem

Allowing client devices to report their own elapsed turn time creates a vulnerability where malicious users can freeze or modify local clock values to never time out.

### Authoritative Elapsed Time Formula

$$\Delta t = \text{Timestamp}_{\text{CurrentMove}} - \text{Timestamp}_{\text{LastMove}}$$

- $\text{Timestamp}_{\text{LastMove}}$: Recorded authoritatively during previous move write.
- $\text{Timestamp}_{\text{CurrentMove}}$: Generated server-side using `FieldValue.serverTimestamp()`.
- **Remaining Time Update**:
  $$\text{TimeRemaining}_{\text{New}} = \max(0, \text{TimeRemaining}_{\text{Old}} - \Delta t)$$

### Visual Countdown vs Authoritative Sync

The Flutter UI runs a local `Timer.periodic(100ms)` strictly to animate digits smoothly between snapshots. When a new snapshot arrives, the local timer instantly resets its base to the authoritative Firestore remaining time value.

---

## 4. 3D Board Rendering Pipeline

The 3D board module (`lib/views/game_board/board_3d/`) is built directly on Flutter's CustomPainter architecture:

1. **ChessSceneController**: Manages horizontal orbit (yaw), vertical tilt (pitch), zoom scale, camera reset, and material themes (Walnut, Obsidian, Cyberpunk, Metal).
2. **PieceModelLoader**: Procedural lathe geometry slicing with smooth normal shading and base collars for all 6 piece types.
3. **Painter's Algorithm Depth-Sorting**: Projects 3D piece centroids into camera-space depth ($z$) and renders background-to-foreground to guarantee artifact-free occlusion.
4. **SquareRaycaster**: Mathematical ray-plane intersection converting 2D screen touches $(x, y)$ to 3D board plane coordinates ($a1..h8$).
5. **MoveAnimationController**: Drives parabolic 3D arcs with quadratic elevation curves and captured piece fade transitions.
6. **Graceful Fallback**: In the event of a graphics context failure, the system throws `RenderInitException` and automatically falls back to the high-performance 2D board.

---

## 5. State Persistence Schema

### Match Document (`/matches/{matchId}`)

- `matchId` (string, UUID v4)
- `whiteUid` (string)
- `blackUid` (string)
- `currentFen` (string, standard FEN format)
- `status` (`MatchStatus` enum string)
- `activeTurn` ('w' or 'b')
- `whiteMillisRemaining` (int)
- `blackMillisRemaining` (int)
- `lastMoveServerTimestamp` (FieldValue.serverTimestamp())
- `createdAt` (FieldValue.serverTimestamp())
- `matchType` ('human' or 'engine')
- `engineDifficulty` (nullable int)
- `moveCount` (int)
- `positionHistory` (`List<String>`)
- `halfmoveClock` (int)
- `processedClientMoveIds` (`List<String>`)
- `drawOfferedBy` (nullable string UID)
- `lastMoveSan` (string)
- `winnerUid` (nullable string)
- `renderMode` ('2d' or '3d')

### Moves Subcollection (`/matches/{matchId}/moves/{moveNumber}`)

- `moveNumber` (int, 1-indexed)
- `san` (string, Standard Algebraic Notation)
- `fenAfterMove` (string, FEN)
- `serverTimestamp` (Timestamp)
- `movedBy` (string UID)
- `clientMoveId` (string UUIDv4)
- `capturedPiece` (nullable string)
- `isCheck` (bool)
- `isCheckmate` (bool)
- `promotionPiece` (nullable string)

---

## 6. Stockfish Isolate Lifecycle

### Constraints

- The native Stockfish binary runs via C++ FFI in a background worker isolate.
- **Single-Instance Invariant**: Exactly one native engine instance can exist per app process.
- **Hot Reload Safety**: The native engine instance and stdout streams are disposed in `ref.onDispose()` and before hot restart.

### UCI Protocol Flow

1. **Initialize**: `uci` -> `isready`
2. **Configure Difficulty**: `setoption name Skill Level value <level>` (0 to 20)
3. **Load Position**: `ucinewgame` -> `position fen <currentFen>`
4. **Evaluate Move**: `go movetime <ms>`
5. **Parse Output**: Listen on stdout for `bestmove <from><to>[promo]` (e.g. `bestmove e7e5` or `bestmove e7e8q`)
6. **Execute**: Submit move to `GameStateNotifier.executeMove()`.

---

## 7. Timeout Detection Architecture Tradeoffs

| Approach | Latency | Cost / Infra | Reliability | Implemented |
| --- | --- | --- | --- | --- |
| **Client-Claim with Transaction Verification** | Instantaneous upon visual timer expiry | $0 (Firestore transaction) | High — verified on server delta | Primary |
| **Scheduled Cloud Function (Sweeper)** | 1 min polling | Minimal Cloud Function runtime | High — independent of client state | Primary |
