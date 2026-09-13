# Implementation Plan: Production Readiness Fixes

This plan details the technical approach to implementing the prioritized fixes identified in the production-readiness audit.

## User Review Required

> [!WARNING]
> **Firebase Deployment:** The Cloud Functions cannot be deployed until the Firebase project is upgraded to the Blaze (pay-as-you-go) plan. I cannot perform this step for you. **Please perform this upgrade in your Firebase Console and let me know when it's done.** If you prefer not to upgrade, we can skip the deployment, but backend-dependent features (multiplayer validation, ELO tracking) will remain broken.

## Proposed Changes

---

### Shared Preferences & Settings State

To persist the local settings (Render Mode, Sound, Reduce Motion), we will introduce a `SettingsService` powered by `shared_preferences`. The Push Notifications setting will also sync to Firestore.

#### [NEW] `lib/services/settings_service.dart`
- Create a `SettingsService` class to wrap `SharedPreferences`.
- Define a Riverpod provider `settingsServiceProvider`.
- Expose methods to get/set `render3d`, `soundEnabled`, `reduceMotion`, and `pushEnabled`.

#### [MODIFY] `lib/views/settings_screen.dart`
- Refactor `SettingsScreen` to read its initial toggle states from `settingsServiceProvider`.
- Update the `onChanged` callbacks to write back to `SettingsService` and `Firestore` (for push notifications).

#### [MODIFY] `lib/views/game_board/game_board_view.dart`
- Read the `render3d` setting from `SettingsService` to decide whether to show the 3D or 2D board initially.

#### [MODIFY] `lib/views/widgets/loading_overlay.dart`
- Read the `reduceMotion` setting. If true, disable the `LiquidGlassContainer` blur effects and use a solid background.

#### [MODIFY] `lib/services/audio_service.dart`
- Read the `soundEnabled` setting before playing sounds.

---

### Profile Screen & Account Management

We need to add editing capabilities, display missing fields, and provide account management options.

#### [MODIFY] `lib/views/profile_screen.dart`
- Add an "Edit" icon/text button next to the Display Name to allow the user to change their name via a dialog prompt. The dialog will enforce character limits.
- Update the UI to display `gamesPlayed` and format the `lastActiveAt` timestamp.
- Add a "View Match History" button that links to a new `MatchHistoryListScreen`.

#### [MODIFY] `lib/views/settings_screen.dart`
- Add "Upgrade Anonymous Account" (only visible if `isAnonymous` is true).
- Add "Delete Account" button with a confirmation dialog.

#### [NEW] `lib/views/match_history_list_screen.dart`
- Create a screen that lists the user's past matches (querying the `matches` collection where `whiteUid` or `blackUid` matches the current user).
- Tapping a match in the list will navigate to the existing `HistoryScreen` for that specific match.

---

### Draw Offer UI

#### [MODIFY] `lib/views/game_board/game_board_view.dart`
- Add a "Draw" action button to the bottom action bar during active play.
- When pressed, update the match document in Firestore to indicate a draw offer (`drawOfferBy`).
- Listen to this field; if the opponent offered a draw, display a dialog or banner allowing the local player to Accept or Decline.

---

## Verification Plan

### Automated Tests
- Run `flutter analyze` and `flutter test` to ensure no regressions.

### Manual Verification
- Test toggling settings and restarting the app to verify persistence.
- Test changing the display name in the Profile Screen.
- Test navigating through the new Match History list.
- (If Firebase is upgraded) Test Cloud Functions deployment.
