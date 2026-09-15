import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:enterprise_chess/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Ghost Player E2-E4 Integration Test', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();

    final passAndPlayButton = find.text('Pass & Play (Local)');
    expect(passAndPlayButton, findsOneWidget);
    await tester.tap(passAndPlayButton);
    await tester.pumpAndSettle();

    final playButton = find.text('Play');
    expect(playButton, findsOneWidget);
    await tester.tap(playButton);
    await tester.pumpAndSettle();

    await Future.delayed(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final toggle3D = find.text('[3D]');
    if (toggle3D.evaluate().isNotEmpty) {
      await tester.tap(toggle3D);
      await tester.pumpAndSettle();
    }

    await Future.delayed(const Duration(seconds: 1));

    final resignBtn = find.text('[RESIGN]');
    if (resignBtn.evaluate().isNotEmpty) {
      await tester.tap(resignBtn);
      await tester.pumpAndSettle();
    }

    final confirmBtn = find.text('Yes');
    if (confirmBtn.evaluate().isNotEmpty) {
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();
    }
  });
}
