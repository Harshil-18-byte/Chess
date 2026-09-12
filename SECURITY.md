# Enterprise Chess — Security & Anti-Cheat Architecture

## 1. Threat Model & Zero-Trust Principles

Enterprise Chess implements a **zero-trust, authoritative-server security model**. No client is trusted to declare:

- Game outcomes (checkmate, stalemate, draws, timeouts).
- Elapsed clock time or remaining time.
- Turn progression or opponent moves.
- Elo rating adjustments.

Every client action undergoes a multi-layer defense pipeline before mutating game state.

```text
Client Device
  │
  ├── 1. App Check Token Verification (SafetyNet / Play Integrity / DeviceCheck)
  ├── 2. Auth State & UID Verification (Firebase Auth)
  ├── 3. Token-Bucket Rate Limiter (Max 10 tokens, refill 2/sec)
  ├── 4. Client Move UUID Idempotency Guard (processedClientMoveIds)
  │
Authoritative Engine / Cloud Function Transaction
  │
  ├── 5. Ban & Suspension Filter
  ├── 6. Turn & Participant Identity Verification (activeTurn matches caller UID)
  ├── 7. Server-Side Move Validation (chess.js / pure Dart engine against prior FEN)
  ├── 8. Authoritative Server Timestamp Clock Deduction (FieldValue.serverTimestamp())
  └── 9. Atomic Multi-Document Firestore Commit (Match doc + immutable Move record)
```

---

## 2. Layered Defense Controls

### 2.1 Firebase App Check

All incoming requests to Cloud Functions and Firestore documents require verified **Firebase App Check** tokens generated via Google Play Integrity (Android) or DeviceCheck/App Attest (iOS). Requests with invalid, expired, or missing tokens are rejected at the edge gateway before invoking application code.

### 2.2 Replay Protection & Idempotency (`clientMoveId`)

Each move submission generates a cryptographic UUIDv4 `clientMoveId` on the client prior to dispatch.

- The authoritative match document maintains a `processedClientMoveIds` array.
- In the atomic Firestore transaction, if `processedClientMoveIds.contains(clientMoveId)`, the transaction aborts with `DuplicateMoveException` (`already-exists`).
- This guarantees that network retries, race conditions, or duplicate packets never apply a move twice or cause out-of-order execution.

### 2.3 Authoritative Server Clocks & Timeouts

Clients **cannot** send their local device time or compute clock decrements.

- Match start and moves record `lastMoveServerTimestamp: FieldValue.serverTimestamp()`.
- On move submission or timeout claims, elapsed time is computed authoritatively on the server:
  $$\Delta t = \text{serverTimestamp} - \text{lastMoveServerTimestamp}$$
- If remaining time drops to $\le 0$, the server terminates the game as `whiteTimeout` or `blackTimeout` and assigns `winnerUid`.
- An autonomous Cloud Function sweeper (`scheduledTimeoutSweeper`) sweeps active matches periodically to finalize games where a player disconnected or abandoned their clock.

### 2.4 Token-Bucket Rate Limiting

Cloud Functions enforce per-UID token buckets (`RateLimiter`):

- Maximum bucket capacity: 10 tokens.
- Refill rate: 2 tokens/second.
- Flood attempts exceeding burst capacity receive `resource-exhausted` HTTP status with `retryAfterSeconds`.

### 2.5 Strict Firestore Security Rules

- **Direct Match Modification Blocked**: Users cannot alter `winnerUid`, `status`, or `currentFen` arbitrarily.
- **Strict Turn Matching**: Move submission requires `request.auth.uid == resource.data.whiteUid` (if `activeTurn == 'w'`) or `request.auth.uid == resource.data.blackUid` (if `activeTurn == 'b'`).
- **Immutable Moves Subcollection**: Documents in `matches/{matchId}/moves/{moveId}` are append-only. Updates and deletes are forbidden.
- **Matchmaking Isolation**: Players can only view, create, or delete their own matchmaking queue entries.

---

## 3. Vulnerability Reporting

For vulnerability disclosures, contact the security team or submit a private report via repository security advisories.
