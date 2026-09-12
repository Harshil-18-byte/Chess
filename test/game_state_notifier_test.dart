import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:enterprise_chess/core/errors/app_exceptions.dart';
import 'package:enterprise_chess/models/chess_match.dart';
import 'package:enterprise_chess/services/firestore_service.dart';
import 'package:enterprise_chess/services/firebase_auth_service.dart';
import 'package:enterprise_chess/state/game_state_notifier.dart';

// Mock auth service returning test UID
class TestAuthService extends FirebaseAuthService {
  final String testUid;
  TestAuthService(this.testUid);

  @override
  String get currentUid => testUid;
}

void main() {
  group('GameStateNotifier Unit Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FirestoreService firestoreService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      firestoreService = FirestoreService(firestore: fakeFirestore);
    });

    test('Legal move e2-e4 updates FEN, sets move record and flips turn to Black', () async {
      final match = await firestoreService.createMatch(
        whiteUid: 'user_white',
        blackUid: 'user_black',
        matchType: 'human',
      );

      final container = ProviderContainer(
        overrides: [
          firestoreServiceProvider.overrideWithValue(firestoreService),
          authServiceProvider.overrideWithValue(TestAuthService('user_white')),
        ],
      );
      addTearDown(container.dispose);

      container.read(activeMatchIdProvider.notifier).setMatchId(match.matchId);

      final notifier = container.read(gameStateNotifierProvider.notifier);
      await container.read(gameStateNotifierProvider.future);

      // Execute legal move
      await notifier.executeMove('e2', 'e4');

      final updatedState = container.read(gameStateNotifierProvider).value!;
      expect(updatedState.activeTurn, 'b');
      expect(updatedState.currentFen.startsWith('rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3'), isTrue);
      expect(updatedState.lastMoveSan, isNotNull);
      expect(updatedState.status, MatchStatus.active);
      expect(updatedState.processedClientMoveIds.length, 1);
    });

    test('Illegal move throws IllegalMoveException and does not mutate match state', () async {
      final match = await firestoreService.createMatch(
        whiteUid: 'user_white',
        blackUid: 'user_black',
        matchType: 'human',
      );

      final container = ProviderContainer(
        overrides: [
          firestoreServiceProvider.overrideWithValue(firestoreService),
          authServiceProvider.overrideWithValue(TestAuthService('user_white')),
        ],
      );
      addTearDown(container.dispose);

      container.read(activeMatchIdProvider.notifier).setMatchId(match.matchId);

      final notifier = container.read(gameStateNotifierProvider.notifier);
      await container.read(gameStateNotifierProvider.future);

      // Attempt illegal move (Knight cannot move straight 4 squares)
      expect(
        () async => await notifier.executeMove('b1', 'b5'),
        throwsA(isA<IllegalMoveException>()),
      );

      final currentState = container.read(gameStateNotifierProvider).value!;
      expect(currentState.activeTurn, 'w');
      expect(currentState.lastMoveSan, isNull);
    });

    test('Move out of turn throws OutOfTurnException', () async {
      final match = await firestoreService.createMatch(
        whiteUid: 'user_white',
        blackUid: 'user_black',
        matchType: 'human',
      );

      // Logged in as Black attempting to move on White's turn
      final container = ProviderContainer(
        overrides: [
          firestoreServiceProvider.overrideWithValue(firestoreService),
          authServiceProvider.overrideWithValue(TestAuthService('user_black')),
        ],
      );
      addTearDown(container.dispose);

      container.read(activeMatchIdProvider.notifier).setMatchId(match.matchId);

      final notifier = container.read(gameStateNotifierProvider.notifier);
      await container.read(gameStateNotifierProvider.future);

      expect(
        () async => await notifier.executeMove('e7', 'e5'),
        throwsA(isA<OutOfTurnException>()),
      );
    });

    test('Checkmate sequence updates MatchStatus to whiteWonCheckmate', () async {
      // Scholar's Mate pre-move position
      const scholarsPreMateFen =
          'r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4';

      final match = await firestoreService.createMatch(
        whiteUid: 'user_white',
        blackUid: 'user_black',
        matchType: 'human',
      );

      // Update match to pre-mate FEN
      await fakeFirestore
          .collection('matches')
          .doc(match.matchId)
          .update({'currentFen': scholarsPreMateFen, 'activeTurn': 'w'});

      final container = ProviderContainer(
        overrides: [
          firestoreServiceProvider.overrideWithValue(firestoreService),
          authServiceProvider.overrideWithValue(TestAuthService('user_white')),
        ],
      );
      addTearDown(container.dispose);

      container.read(activeMatchIdProvider.notifier).setMatchId(match.matchId);

      final notifier = container.read(gameStateNotifierProvider.notifier);
      await container.read(gameStateNotifierProvider.future);

      // White delivers checkmate Qxf7#
      await notifier.executeMove('h5', 'f7');

      final updatedState = container.read(gameStateNotifierProvider).value!;
      expect(updatedState.status, MatchStatus.whiteWonCheckmate);
      expect(updatedState.winnerUid, 'user_white');
    });

    test('Stalemate move updates MatchStatus to drawStalemate', () async {
      const preStalemateFen = '4k3/8/4K3/3Q4/8/8/8/8 w - - 0 1';

      final match = await firestoreService.createMatch(
        whiteUid: 'user_white',
        blackUid: 'user_black',
        matchType: 'human',
      );

      await fakeFirestore
          .collection('matches')
          .doc(match.matchId)
          .update({'currentFen': preStalemateFen, 'activeTurn': 'w'});

      final container = ProviderContainer(
        overrides: [
          firestoreServiceProvider.overrideWithValue(firestoreService),
          authServiceProvider.overrideWithValue(TestAuthService('user_white')),
        ],
      );
      addTearDown(container.dispose);

      container.read(activeMatchIdProvider.notifier).setMatchId(match.matchId);

      final notifier = container.read(gameStateNotifierProvider.notifier);
      await container.read(gameStateNotifierProvider.future);

      // White plays Qd6 -> causes stalemate for Black
      await notifier.executeMove('d5', 'd6');

      final updatedState = container.read(gameStateNotifierProvider).value!;
      expect(updatedState.status, MatchStatus.drawStalemate);
    });

    test('Claiming timeout transitions state to timeout status', () async {
      final match = await firestoreService.createMatch(
        whiteUid: 'user_white',
        blackUid: 'user_black',
        matchType: 'human',
      );

      final container = ProviderContainer(
        overrides: [
          firestoreServiceProvider.overrideWithValue(firestoreService),
          authServiceProvider.overrideWithValue(TestAuthService('user_white')),
        ],
      );
      addTearDown(container.dispose);

      container.read(activeMatchIdProvider.notifier).setMatchId(match.matchId);

      final notifier = container.read(gameStateNotifierProvider.notifier);
      await container.read(gameStateNotifierProvider.future);

      await notifier.claimTimeoutWin('b');

      final updatedState = container.read(gameStateNotifierProvider).value!;
      expect(updatedState.status, MatchStatus.blackTimeout);
      expect(updatedState.winnerUid, 'user_white');
    });
  });
}
