import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:enterprise_chess/main.dart';
import 'package:enterprise_chess/services/firebase_auth_service.dart';
import 'package:enterprise_chess/services/firestore_service.dart';
import 'package:enterprise_chess/state/game_state_notifier.dart';
import 'package:enterprise_chess/views/dashboard/home_screen.dart';

class TestAuthService extends FirebaseAuthService {
  final String testUid;
  TestAuthService(this.testUid);

  @override
  String get currentUid => testUid;
}

void main() {
  testWidgets('EnterpriseChessApp boots successfully into HomeScreen', (WidgetTester tester) async {
    final fakeFirestore = FakeFirebaseFirestore();
    final firestoreService = FirestoreService(firestore: fakeFirestore);
    final authService = TestAuthService('test_user_123');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreServiceProvider.overrideWithValue(firestoreService),
          authServiceProvider.overrideWithValue(authService),
        ],
        child: const EnterpriseChessApp(),
      ),
    );

    // Pump frames to complete async initialization
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Title and HomeScreen elements
    expect(find.text('Chessical'), findsWidgets);
    expect(find.text('CHESSICAL'), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
