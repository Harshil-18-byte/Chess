# Production Readiness Fixes

## Priority 1: Core Gameplay & Security
- `[x]` **1. Deploy Cloud Functions:** SKIPPED - Firebase will remain on Spark plan.
- `[x]` **2. Settings Screen Persistence:** Wire the Settings UI to `SharedPreferences` for local toggles (Render Mode, Sound, Reduce Motion) and `Firestore` for Push Notifications.
- `[x]` **3. Profile Screen Missing Elements:** Add UI to edit `displayName`. Display `gamesPlayed` and `lastActiveAt`. Implement `isBanned` check before matchmaking.

## Priority 2: Full User-Facing Flows
- `[x]` **4. Match History List:** Build a screen showing a list of past matches for the user to select from, linking the Profile Screen to it.
- `[x]` **5. Draw Offer UI:** Implement the draw-offer / accept UI flow in the game board.
- `[x]` **6. Account Management:** Add "Upgrade Anonymous Account" and "Delete Account" actions to the Settings screen.

## Priority 3: Visual / Polish Gaps
- `[x]` **7. Reduce Motion Enforcement:** Wire the `Reduce Motion` setting to globally disable `LiquidGlassContainer` blurs.
- `[x]` **8. Sound Control Enforcement:** Wire the `Sound Effects` setting to mute the audio service.
