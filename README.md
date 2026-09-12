# Chessical ♚

![Chessical Logo](assets/images/logo.png)

A production-grade, zero-exploit, full-stack reactive Chess application built with **Flutter (Dart)**, **Firebase (Auth, Firestore, App Check, Cloud Functions)** for tamper-proof multiplayer synchronization, and a local on-device **Stockfish FFI engine** with dual **2D / 3D Board Rendering** themed in Obsidian & Magma Ember.

---

## Architecture Overview

```text
                      +-------------------------------------------------+
                      |              Flutter UI Layer                   |
                      |   (2D Grid Canvas & 3D CustomPainter Viewport)  |
                      |          (GameBoardView, GameClock, Lobby)      |
                      +------------------------+------------------------+
                                               |
                                               | Reactive Watch / Dispatch
                                               v
                      +-------------------------------------------------+
                      |           Riverpod State Layer                  |
                      |           (GameStateNotifier)                   |
                      +------------+-----------------------+------------+
                                   |                       |
           Local Move Validation   |                       | Single-Player
           via pure Dart `chess`   |                       | Engine Mode
                                   v                       v
                   +-----------------------+   +-----------------------+
                   |  Authoritative Move   |   | On-Device Stockfish   |
                   |  Calculation & SAN    |   | Background Isolate    |
                   +-----------+-----------+   | (UCI / FEN via FFI)   |
                               |               +-----------------------+
                   Firestore   |
                   Atomic Tx   |
                               v
                   +-----------------------+
                   | Cloud Firestore /     |
                   | Firebase Functions    |
                   | (matches/{id})        |
                   | (moves/{moveId})      |
                   +-----------------------+
```

---

## Key Architectural Principles

1. **Zero LLM Inference in Game Logic**: Move legality, check, checkmate, stalemate, threefold repetition, 50-move rule, 4 insufficient-material cases, and castling rights are computed exclusively by the pure-Dart `chess` engine.
2. **3D Real-Time Board & Piece Pipeline**: Full 3D perspective rendering (`lib/views/game_board/board_3d/`) featuring camera orbit/zoom gestures, screen-to-3D-square raycasting (`SquareRaycaster`), procedural lathe piece meshes, depth-sorted rendering (Painter's algorithm), and graceful 2D fallback.
3. **Immutable State with Riverpod**: UI components are pure reactive consumers of `AsyncValue<ChessMatch>`. No widget mutates state directly.
4. **Tamper-Proof Clocks**: Client clocks are strictly visual tickers. Elapsed turn time is computed server-side via `FieldValue.serverTimestamp()` deltas (`Timestamp_CurrentMove - Timestamp_LastMove`).
5. **Zero-Trust Security & Idempotency**: Cryptographic UUIDv4 `clientMoveId` replay protection, turn-matching Firestore security rules, token-bucket rate limiting, and server-side Cloud Functions.
6. **Hybrid Multiplayer & On-Device Engine**: Real-time 2-player matchmaking over Firestore reactive streams, with local background Stockfish FFI evaluation for zero network latency single-player play.

---

## Installation & Setup

### Prerequisites

- **Flutter SDK**: `>=3.19.0 <4.0.0`
- **Dart SDK**: `^3.12.1`
- **Firebase CLI**: `npm install -g firebase-tools`
- **FlutterFire CLI**: `dart pub global activate flutterfire_cli`

### 1. Clone & Install Dependencies

```bash
git clone https://github.com/your-org/enterprise-chess.git
cd enterprise-chess
flutter pub get
```

### 2. Configure Firebase & Deploy Rules / Functions

Login to Firebase and link your project:

```bash
firebase login
flutterfire configure --project=your-firebase-project-id
firebase deploy --only firestore:rules,functions
```

---

## Running the Application

### Android

```bash
flutter run -d android
```

> **Note**: Requires `minSdkVersion = 21` (or `24` for 16KB memory page size optimization in Android 15+).

### iOS

```bash
flutter run -d ios
```

> **Note**: Requires iOS Deployment Target `>= 13.0`.

### Desktop (Windows / macOS / Linux) & Web

```bash
flutter run -d windows
flutter run -d chrome
```

---

## Running Automated Tests

Run all 33 unit, transaction, rules, 3D raycasting, and E2E simulation tests:

```bash
flutter test
```

Run static analysis with zero tolerance for warnings:

```bash
dart analyze lib test
```

---

## Dependencies & Version Constraints

| Package | Version | Purpose |
| --- | --- | --- |
| `chess` | `^0.8.1` | Pure Dart authoritative chess rules & state validation |
| `flutter_riverpod` | `^2.6.1` | Reactive immutable state management |
| `firebase_core` | `^3.12.1` | Firebase initial setup and platform channels |
| `firebase_auth` | `^5.5.3` | Anonymous & email authentication sessions |
| `cloud_firestore` | `^5.6.7` | Real-time documents, atomic transactions, move audit log |
| `stockfish_flutter_plus` | `^1.0.1` | Background isolate Stockfish FFI engine |
| `google_fonts` | `^6.3.3` | Premium typography (Inter) |
| `uuid` | `^4.6.0` | Cryptographic match & idempotency move ID generation |
| `fake_cloud_firestore` | `^4.2.0` | Mock Firestore harness for unit & transaction tests |