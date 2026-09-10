import 'package:flutter_test/flutter_test.dart';

import 'package:parable_bloom/features/game/presentation/widgets/celebration_effects.dart';

void main() {
  group('pickCongratulationMessage', () {
    test('returns a message from the shared list', () {
      expect(kCongratulationMessages, contains(pickCongratulationMessage()));
    });

    test('shared list covers both screens without duplication', () {
      // Game and tutorial previously carried identical 15-item copies.
      expect(kCongratulationMessages, hasLength(15));
      expect(kCongratulationMessages.toSet(), hasLength(15));
    });

    test('supports a custom list', () {
      expect(pickCongratulationMessage(['only']), 'only');
    });
  });
}
