import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parable_bloom/core/widgets/constrained_page.dart';

Finder _pageBox() => find.byWidgetPredicate(
      (w) => w is ConstrainedBox && w.constraints.maxWidth == 680,
    );

void main() {
  group('ConstrainedPage', () {
    testWidgets('caps child width on wide screens', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConstrainedPage(
              maxWidth: 680,
              child: SizedBox.expand(),
            ),
          ),
        ),
      );

      final box = tester.getRect(_pageBox());
      expect(box.width, 680);
    });

    testWidgets('fills narrow screens', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConstrainedPage(
              maxWidth: 680,
              child: SizedBox.expand(),
            ),
          ),
        ),
      );

      final box = tester.getRect(_pageBox());
      expect(box.width, 390);
    });

    testWidgets('centers content horizontally', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConstrainedPage(
              maxWidth: 680,
              child: SizedBox.expand(),
            ),
          ),
        ),
      );

      final box = tester.getRect(_pageBox());
      expect(box.left, (1600 - 680) / 2);
    });
  });
}
