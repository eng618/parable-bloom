import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:parable_bloom/app/parable_bloom_app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App launches successfully', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: ParableBloomApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify something on the home screen exists
    expect(find.text('Parable Bloom'), findsOneWidget);
  });
}
