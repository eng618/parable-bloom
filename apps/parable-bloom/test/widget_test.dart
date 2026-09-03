import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Basic widget test', (WidgetTester tester) async {
    // Simple smoke test - just verify basic Flutter widget rendering works
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(56),
            child: SizedBox(),
          ),
          body: Center(child: Text('Parable Bloom')),
        ),
      ),
    );

    expect(find.text('Parable Bloom'), findsOneWidget);
  });
}
