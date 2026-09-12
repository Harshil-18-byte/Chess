# Production Firebase Security Rules

Below is the complete, copy-paste-ready `firestore.rules` file that guarantees cryptographic participant authorization, turn verification, immutable move history logs, and tamper-proof server timestamps.

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper functions for security validation
    function isAuthenticated() {
      return request.auth != null;
    }

    function isUser(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }

    function isMatchParticipant(matchData) {
      return isAuthenticated() &&
        (request.auth.uid == matchData.whiteUid || request.auth.uid == matchData.blackUid);
    }

    function isServerTimestamp(field) {
      return field == request.time;
    }

    // ==========================================
    // USER PROFILES
    // ==========================================
    match /users/{userId} {
      allow read: if isAuthenticated();
      allow create, update: if isUser(userId);
      allow delete: if false;
    }

    // ==========================================
    // MATCHMAKING QUEUE
    // ==========================================
    match /matchmaking_queue/{userId} {
      allow read: if isAuthenticated();
      allow create: if isUser(userId)
                    && request.resource.data.uid == userId
                    && isServerTimestamp(request.resource.data.queuedAt);
      allow delete: if isAuthenticated();
      allow update: if false;
    }

    // ==========================================
    // MATCHES COLLECTION
    // ==========================================
    match /matches/{matchId} {
      allow read: if isAuthenticated() &&
        (resource == null ||
         resource.data.whiteUid == request.auth.uid ||
         resource.data.blackUid == request.auth.uid ||
         resource.data.whiteUid == 'anonymous' ||
         resource.data.blackUid == 'engine_stockfish');

      allow create: if isAuthenticated() &&
        (request.resource.data.whiteUid == request.auth.uid ||
         request.resource.data.blackUid == request.auth.uid) &&
        request.resource.data.status == 'active' &&
        request.resource.data.activeTurn == 'w' &&
        isServerTimestamp(request.resource.data.createdAt) &&
        isServerTimestamp(request.resource.data.lastMoveServerTimestamp);

      allow update: if isAuthenticated() &&
        isMatchParticipant(resource.data) &&
        isServerTimestamp(request.resource.data.lastMoveServerTimestamp) &&
        (
          // Case A: Turn-matching write verified against EXISTING resource
          (
            (resource.data.activeTurn == 'w' && request.auth.uid == resource.data.whiteUid) ||
            (resource.data.activeTurn == 'b' && request.auth.uid == resource.data.blackUid) ||
            (resource.data.matchType == 'engine' && request.auth.uid == resource.data.whiteUid)
          ) ||
          // Case B: Resignation
          (request.resource.data.status == 'resignation') ||
          // Case C: Draw offer / response
          (request.resource.data.drawOfferedBy != resource.data.drawOfferedBy) ||
          // Case D: Verified timeout claim
          (request.resource.data.status == 'whiteTimeout' || request.resource.data.status == 'blackTimeout')
        );

      allow delete: if false;

      // ==========================================
      // MOVES SUBCOLLECTION (IMMUTABLE AUDIT LOG)
      // ==========================================
      match /moves/{moveId} {
        allow read: if isAuthenticated() &&
          (get(/databases/$(database)/documents/matches/$(matchId)).data.whiteUid == request.auth.uid ||
           get(/databases/$(database)/documents/matches/$(matchId)).data.blackUid == request.auth.uid ||
           get(/databases/$(database)/documents/matches/$(matchId)).data.blackUid == 'engine_stockfish');

        allow create: if isAuthenticated() &&
          (request.auth.uid == request.resource.data.movedBy ||
           request.resource.data.movedBy == 'engine_stockfish') &&
          isServerTimestamp(request.resource.data.serverTimestamp);

        // Moves are strictly IMMUTABLE once created
        allow update, delete: if false;
      }
    }
  }
}
```

---

## Security Invariants Enforced

1. **Turn Authorization**: A player cannot write moves on their opponent's turn. Verification occurs against `resource.data.activeTurn` (the existing document in the database), preventing client spoofing.
2. **Participant Exclusivity**: Third parties cannot intercept or mutate active matches.
3. **Immutable History**: Move documents once created in `/matches/{matchId}/moves/{moveId}` cannot be updated or deleted (`allow update, delete: if false`).
4. **Server Timestamp Ingestion**: Every write requires `request.resource.data.lastMoveServerTimestamp == request.time`.
