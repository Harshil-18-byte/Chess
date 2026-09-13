import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:enterprise_chess/models/chess_match.dart';
import 'package:enterprise_chess/models/user_profile.dart';
import 'package:enterprise_chess/services/firestore_service.dart';
import 'package:enterprise_chess/services/firebase_auth_service.dart';
import 'package:enterprise_chess/state/game_state_notifier.dart';
import 'package:enterprise_chess/views/game_board/board_3d/square_raycaster.dart';
import 'package:enterprise_chess/views/game_board/board_3d/piece_model_loader.dart';

class MockAuthService extends FirebaseAuthService {
  String _currentUid;
  MockAuthService(this._currentUid);

  void setUid(String uid) => _currentUid = uid;

  @override
  String get currentUid => _currentUid;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('E2E Match Simulation & Pipeline Verification', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FirestoreService firestoreService;
    late MockAuthService mockAuth;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      firestoreService = FirestoreService(firestore: fakeFirestore);
      mockAuth = MockAuthService('user_white');
    });

    test('Full End-to-End Human vs Human Checkmate Game Simulation (Scholar\'s Mate)', () async {
      // 1. Create Initial User Profiles
      await firestoreService.saveUserProfile(UserProfile(
        uid: 'user_white',
        displayName: 'White Grandmaster',
        eloRating: 1500,
        gamesPlayed: 0,
        wins: 0,
        losses: 0,
        draws: 0,
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      ));

      await firestoreService.saveUserProfile(UserProfile(
        uid: 'user_black',
        displayName: 'Black Contender',
        eloRating: 1500,
        gamesPlayed: 0,
        wins: 0,
        losses: 0,
        draws: 0,
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      ));

      // 2. Create Live Match
      final match = await firestoreService.createMatch(
        whiteUid: 'user_white',
        blackUid: 'user_black',
        matchType: 'human',
        timeControlMillis: 600000,
      );

      final container = ProviderContainer(
        overrides: [
          firestoreServiceProvider.overrideWithValue(firestoreService),
          authServiceProvider.overrideWithValue(mockAuth),
        ],
      );
      addTearDown(container.dispose);

      container.read(activeMatchIdProvider.notifier).setMatchId(match.matchId);
      final notifier = container.read(gameStateNotifierProvider.notifier);
      await container.read(gameStateNotifierProvider.future);

      // --- Move 1: White 1. e4 ---
      mockAuth.setUid('user_white');
      await notifier.executeMove('e2', 'e4');
      var state = container.read(gameStateNotifierProvider).value!;
      expect(state.activeTurn, 'b');
      expect(state.moveCount, 1);

      // --- Move 1: Black 1... e5 ---
      mockAuth.setUid('user_black');
      await notifier.executeMove('e7', 'e5');
      state = container.read(gameStateNotifierProvider).value!;
      expect(state.activeTurn, 'w');
      expect(state.moveCount, 2);

      // --- Move 2: White 2. Bc4 ---
      mockAuth.setUid('user_white');
      await notifier.executeMove('f1', 'c4');
      state = container.read(gameStateNotifierProvider).value!;
      expect(state.activeTurn, 'b');
      expect(state.moveCount, 3);

      // --- Move 2: Black 2... Nc6 ---
      mockAuth.setUid('user_black');
      await notifier.executeMove('b8', 'c6');
      state = container.read(gameStateNotifierProvider).value!;
      expect(state.activeTurn, 'w');
      expect(state.moveCount, 4);

      // --- Move 3: White 3. Qh5 ---
      mockAuth.setUid('user_white');
      await notifier.executeMove('d1', 'h5');
      state = container.read(gameStateNotifierProvider).value!;
      expect(state.activeTurn, 'b');
      expect(state.moveCount, 5);

      // --- Move 3: Black 3... Nf6 (Blunder allowing mate) ---
      mockAuth.setUid('user_black');
      await notifier.executeMove('g8', 'f6');
      state = container.read(gameStateNotifierProvider).value!;
      expect(state.activeTurn, 'w');
      expect(state.moveCount, 6);

      // --- Move 4: White 4. Qxf7# (Checkmate!) ---
      mockAuth.setUid('user_white');
      await notifier.executeMove('h5', 'f7');
      state = container.read(gameStateNotifierProvider).value!;

      // 3. Verify End Game State
      expect(state.status, MatchStatus.whiteWonCheckmate);
      expect(state.winnerUid, 'user_white');
      expect(state.moveCount, 7);
      expect(state.processedClientMoveIds.length, 7);

      // 4. Update Stats and Verify Elo Delta
      await firestoreService.updateUserStats(
        uid: 'user_white',
        eloDelta: 16,
        isWin: true,
        isLoss: false,
        isDraw: false,
        isTimedMatch: true,
      );

      await firestoreService.updateUserStats(
        uid: 'user_black',
        eloDelta: -16,
        isWin: false,
        isLoss: true,
        isDraw: false,
        isTimedMatch: true,
      );

      final whiteProfile = await firestoreService.getUserProfile('user_white');
      final blackProfile = await firestoreService.getUserProfile('user_black');

      expect(whiteProfile?.eloRating, 1516);
      expect(whiteProfile?.wins, 1);
      expect(whiteProfile?.gamesPlayed, 1);

      expect(blackProfile?.eloRating, 1484);
      expect(blackProfile?.losses, 1);
      expect(blackProfile?.gamesPlayed, 1);
    });

    test('3D Square Raycaster translates centered touch points to accurate chess coordinates', () {
      const viewportSize = Size(400, 400);

      // Tap direct center of board: center spans d4/e4/d5/e5
      final centerSquare = SquareRaycaster.raycast(
        const Offset(200, 200),
        viewportSize,
        pitch: 0.85,
        yaw: 0.0,
        zoom: 1.0,
        isFlipped: false,
      );

      expect(centerSquare, isNotNull);
      expect(['d4', 'd5', 'e4', 'e5'].contains(centerSquare), isTrue);

      // Tap way out of bounds returns null
      final oobSquare = SquareRaycaster.raycast(
        const Offset(5000, 5000),
        viewportSize,
        pitch: 0.85,
        yaw: 0.0,
        zoom: 1.0,
        isFlipped: false,
      );
      expect(oobSquare, isNull);
    });

    test('3D Piece Model Loader loads all 6 piece profiles with valid lathe rings', () {
      final pieces = ['K', 'Q', 'R', 'B', 'N', 'P'];
      for (final p in pieces) {
        final profile = Piece3DProfile.getProfile(p);
        expect(profile.rings.isNotEmpty, isTrue);
        expect(profile.baseRadius, greaterThan(0.2));
        expect(profile.totalHeight, greaterThan(0.5));

        // Base ring height starts at 0.0
        expect(profile.rings.first.height, 0.0);
        // Top ring height reaches 1.0
        expect(profile.rings.last.height, 1.0);
      }
    });
  });
}
