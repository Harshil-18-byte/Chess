# Chessical // Credits & Open Source License Acknowledgements

The Chessical platform is built upon high-performance open-source software libraries, mathematical foundations, 3D asset standards, and native chess engines. We acknowledge and thank the maintainers and communities behind these projects:

---

## 1. Native Chess Engines & Engine Bridges

### Stockfish Chess Engine
- **Source**: [Stockfish Engine Project](https://stockfishchess.org/)
- **Authors**: Tord Romstad, Marco Costalba, Joona Kiiski, Gary Linscott, and the Stockfish Community
- **License**: GNU General Public License v3.0 (GPLv3)
- **Role**: Native C++ chess engine executing in dedicated Dart background isolates for zero-latency single-player mode.

### stockfish_flutter_plus
- **Source**: [pub.dev/packages/stockfish_flutter_plus](https://pub.dev/packages/stockfish_flutter_plus)
- **License**: MIT License
- **Role**: Dart FFI bridge for cross-platform Android (16KB page-aligned), iOS, Windows, and macOS native runtime execution.

---

## 2. Chess Rules & Evaluation Libraries

### chess (Dart)
- **Source**: [pub.dev/packages/chess](https://pub.dev/packages/chess)
- **Author**: Jeremy R. Weiskotten / Pedro A. Velasquez
- **License**: BSD 2-Clause License
- **Role**: Pure-Dart deterministic move calculation, SAN generation, FEN state decoding, and terminal board invariant evaluations.

### chess.js (TypeScript)
- **Source**: [github.com/jhlywa/chess.js](https://github.com/jhlywa/chess.js)
- **Author**: Jeff Hlywa
- **License**: BSD 2-Clause License
- **Role**: Server-side authoritative move re-validation in Firebase Cloud Functions (`validateMove.ts`).

---

## 3. Reactive State Management & UI Framework

### Flutter & Dart SDKs
- **Organization**: Google LLC / Flutter Open Source Community
- **License**: BSD 3-Clause License
- **Role**: High-performance multi-platform UI framework and reactive rendering engine.

### Flutter Riverpod
- **Author**: Remi Rousselet
- **License**: MIT License
- **Role**: Declarative, compile-time safe, immutable state management (`AsyncNotifierProvider`).

### Google Fonts (Inter & Courier)
- **Authors**: Rasmus Andersson / Google Design Team
- **License**: SIL Open Font License 1.1 (OFL)
- **Role**: Typography tokens for user profile statistics, game clock digits, and dashboard headers.

---

## 4. 3D Lathe Geometry & Asset Architecture

### Poly Haven & Public Domain Game Assets
- **Source**: [Poly Haven](https://polyhaven.com/) / Public Domain 3D Models
- **License**: CC0 1.0 Universal (Public Domain Dedication)
- **Role**: Base parametric profiles for procedural King, Queen, Rook, Bishop, Knight, and Pawn lathe mesh structures.

### Chessical Obsidian & Magma Artwork
- **Asset**: `assets/images/logo.png`
- **Ownership**: Chessical Community
- **Description**: Fractured obsidian and molten ember core King and Queen 3D render.

---

## 5. Backend Services & Cloud Infrastructure

### Firebase SDKs (Core, Auth, Firestore, App Check, Cloud Functions)
- **Organization**: Google LLC
- **License**: Apache License 2.0
- **Role**: Real-time ACID document database, phone/anonymous authentication, cryptographic App Check attestation, and serverless compute.
