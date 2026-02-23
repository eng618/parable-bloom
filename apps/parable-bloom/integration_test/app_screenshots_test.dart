import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:parable_bloom/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture home screen', (tester) async {
    app.main();

    // Allow app startup, Firebase, and Hive to settle before capture.
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await binding.takeScreenshot('home');
  });
}
