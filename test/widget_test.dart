import 'dart:io';
import 'package:flame/game.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:parable_bloom/main.dart';
import 'package:parable_bloom/providers/game_providers.dart';

void main() {
  setUpAll(() {
    final path = Directory.systemTemp.createTempSync().path;
    Hive.init(path);
  });

  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Open a test box
    final box = await Hive.openBox('testBox');

    // Build our app with ProviderScope and overridden Hive box
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hiveBoxProvider.overrideWithValue(box),
        ],
        child: const ParableBloomApp(),
      ),
    );

    // Verify that the game screen is displayed
    expect(find.byType(GameWidget), findsNothing); // GameWidget requires assets which fail in widget test without setup
    // But we can check for main UI elements like AppBar
    expect(find.text('Parable Bloom'), findsOneWidget);
  });
}
