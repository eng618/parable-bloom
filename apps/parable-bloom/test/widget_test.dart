import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Basic widget test', (WidgetTester tester) async {
    // Simple smoke test - just verify basic Flutter widget rendering works
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: Text('Test App')),
          body: Center(child: Text('Hello World')),
        ),
      ),
    );

    expect(find.text('Test App'), findsOneWidget);
    expect(find.text('Hello World'), findsOneWidget);
  });
}
