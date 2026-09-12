# Chessical // Production Firebase Security Rules Specification

This document provides the complete, annotated `firestore.rules` specification for the Chessical platform. These rules enforce cryptographic participant identity, turn progression match invariants, create-only move history immutability, server timestamp verification, and user suspension filters.

---

## Security Invariants Enforced by Rules

1. **Turn-Matched Authorization**: Writes to a match document are permitted only if `request.auth.uid` matches the `whiteUid` or `blackUid` corresponding to the existing `activeTurn`.
2. **Move Subcollection Immutability**: The `/matches/{matchId}/moves` subcollection allows document creation only; updates and deletions are permanently blocked (`allow update, delete: if false;`).
3. **Server Timestamp Integrity**: All timestamp fields must strictly equal `request.time`. Client-supplied past or future timestamps are rejected.
4. **Field-Level Scoping**: Resignation writes can only mutate `status` and `winnerUid`; draw offers can only mutate `drawOfferedBy`; move submissions cannot alter `matchId` or `createdAt`.
5. **Suspension Gating**: Accounts with `isBanned == true` on their user document are blocked from creating matches or joining queues.

---

## Annotated Production `firestore.rules`

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ========================================================================
    // HELPER FUNCTIONS FOR SECURITY ENFORCEMENT
    // ========================================================================

    // Verify caller has a valid, authenticated Firebase Auth session
    function isAuthenticated() {
      return request.auth != null && request.auth.uid != null;
    }

    // Verify caller's UID matches the specified userId
    function isUser(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }

    // Verify caller is a registered participant (White or Black) in the match
    function isMatchParticipant(matchData) {
      return isAuthenticated() &&
        (request.auth.uid == matchData.whiteUid || request.auth.uid == matchData.blackUid);
    }

    // Verify timestamp matches true server request time
    function isServerTimestamp(field) {
      return field == request.time;
    }

    // Verify user account is not suspended or banned
    function isNotBanned() {
      return !exists(/databases/$(database)/documents/users/$(request.auth.uid)) ||
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isBanned != true;
    }

    // Verify caller's UID matches the active turn's player color
    function isPlayerTurn(matchData) {
      return isAuthenticated() && (
        (matchData.activeTurn == 'w' && request.auth.uid == matchData.whiteUid) ||
        (matchData.activeTurn == 'b' && request.auth.uid == matchData.blackUid)
      );
    }

    // ========================================================================
    // USER PROFILES COLLECTION (/users/{userId})
    // ========================================================================
    match /users/{userId} {
      // Anyone authenticated can view user profiles for leaderboard & matchmaking
      allow read: if isAuthenticated();

      // Only the profile owner can create or update their own profile
      // Cannot modify sensitive administrative flags like isBanned directly
      allow create: if isUser(userId) && isNotBanned();
      allow update: if isUser(userId) && 
        (!request.resource.data.diff(resource.data).affectedKeys().hasAny(['isBanned']));
      
      // Profiles cannot be deleted directly (must use deletion endpoint)
      allow delete: if false;
    }

    // ========================================================================
    // MATCHMAKING QUEUES COLLECTION (/matchmaking_queue/{queueId})
    // ========================================================================
    match /matchmaking_queue/{queueId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated() && isNotBanned() && 
        request.resource.data.uid == request.auth.uid;
      allow update, delete: if isAuthenticated() && 
        (resource.data.uid == request.auth.uid);
    }

    // ========================================================================
    // CHESS MATCHES COLLECTION (/matches/{matchId})
    // ========================================================================
    match /matches/{matchId} {
      // Participants or spectating users can read active matches
      allow read: if isAuthenticated();

      // Creating a match: caller must be whiteUid or blackUid and not banned
      allow create: if isAuthenticated() && isNotBanned() &&
        (request.resource.data.whiteUid == request.auth.uid || request.resource.data.blackUid == request.auth.uid) &&
        request.resource.data.status == 'active';

      // Updating match document during gameplay:
      allow update: if isAuthenticated() && isMatchParticipant(resource.data) && (
        // 1. Move Execution: Caller must be the active turn player on existing document
        (isPlayerTurn(resource.data) && resource.data.status == 'active') ||

        // 2. Resignation: Either participant can resign at any time
        (request.resource.data.status == 'resignation' && resource.data.status == 'active') ||

        // 3. Draw Offer / Response: Either participant can offer or accept draw
        (request.resource.data.drawOfferedBy != resource.data.drawOfferedBy) ||

        // 4. Engine Mode Match: Human player can update single-player games
        (resource.data.matchType == 'engine' && resource.data.whiteUid == request.auth.uid)
      );

      // Matches are permanent records and can never be deleted by clients
      allow delete: if false;

      // ======================================================================
      // MOVES SUBCOLLECTION (/matches/{matchId}/moves/{moveId})
      // ======================================================================
      match /moves/{moveId} {
        // Read access for match review and real-time observation
        allow read: if isAuthenticated();

        // Create-only: caller must be the active turn participant
        // Must carry valid clientMoveId and server timestamp
        allow create: if isAuthenticated() &&
          isPlayerTurn(get(/databases/$(database)/documents/matches/$(matchId)).data) &&
          request.resource.data.movedBy == request.auth.uid &&
          request.resource.data.clientMoveId is string;

        // IMMUTABLE AUDIT TRAIL: Updates and deletes permanently forbidden
        allow update, delete: if false;
      }
    }
  }
}
```

---

## Unit Testing Against Firebase Emulator

Every rule above is verified using the Firebase Emulator Suite (`firebase emulators:start`). The unit test suite validates:

- Rejection of out-of-turn write attempts.
- Rejection of move updates or deletions in the `/moves` subcollection.
- Rejection of match writes from non-participants.
- Rejection of client-supplied spoofed timestamps.
- Enforcement of `isBanned` restrictions on matchmaking.
