import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/features/home/presentation/widgets/session_close_sheet.dart';

void main() {
  group('session close / welcome copy pack', () {
    test('welcome messages are non-empty and unique', () {
      expect(kWelcomeBackMessages, isNotEmpty);
      expect(
        kWelcomeBackMessages.toSet(),
        hasLength(kWelcomeBackMessages.length),
      );
      expect(kWelcomeBackMessages, contains(pickWelcomeBackMessage()));
    });

    test('session-close copy matches locked calm pack', () {
      expect(kSessionCloseNoVerseTitle, 'The garden rests.');
      expect(
        kSessionCloseNoVerseBody,
        'Come back tomorrow — another vine awaits.',
      );
      expect(kSessionCloseVerseTitle, 'A seed for tomorrow.');
      expect(kSessionCloseVerseBody, 'Rest with this verse when you return.');
    });
  });
}
