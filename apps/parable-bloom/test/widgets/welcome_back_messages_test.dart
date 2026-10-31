import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/features/home/presentation/widgets/welcome_back_messages.dart';

void main() {
  group('welcome-back copy pack', () {
    test('welcome-back lines are unique and non-empty', () {
      expect(kWelcomeBackMessages, isNotEmpty);
      expect(
        kWelcomeBackMessages.toSet(),
        hasLength(kWelcomeBackMessages.length),
      );
      expect(kWelcomeBackMessages, contains(pickWelcomeBackMessage()));
    });
  });
}
