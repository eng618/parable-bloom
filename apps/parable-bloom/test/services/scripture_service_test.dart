import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/services/scripture_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScriptureService Tests', () {
    late ScriptureService service;

    setUp(() {
      service = ScriptureService();
    });

    test('Loads KJV verses correctly from local database', () async {
      await service.initialize();

      // Test loading Matthew 13:31-32
      final result1 = await service.loadScripture('Matthew 13:31-32', translationId: 'kjv');
      expect(result1['translation'], 'KJV');
      expect(result1['text']!.contains('mustard seed'), true);

      // Test loading Matthew 9:37-38
      final result2 = await service.loadScripture('Matthew 9:37-38', translationId: 'kjv');
      expect(result2['translation'], 'KJV');
      expect(result2['text']!.contains('harvest'), true);
      expect(result2['text']!.contains('labourers'), true);
    });

    test('Gracefully falls back to KJV for unknown translation or invalid online fetch', () async {
      // If we pass 'invalid_id', it should fall back to KJV
      final result = await service.loadScripture('Mark 4:26-29', translationId: 'invalid_id');
      expect(result['translation'], 'KJV');
      expect(result['text']!.contains('kingdom of God'), true);
    });

    test('Returns warning message for completely missing scripture references', () async {
      final result = await service.loadScripture('Genesis 1:1', translationId: 'kjv');
      expect(result['text']!.contains('not found in offline library'), true);
    });

    test('Randomly selects an active translation ID', () async {
      final translationId = await service.pickRandomActiveTranslation();
      expect(translationId.isNotEmpty, true);
      // Valid active translations from metadata config: web, kjv, net, esv, csb (subject to connectivity)
      final validActive = {'web', 'kjv', 'net', 'esv', 'csb'};
      expect(validActive.contains(translationId), true, reason: 'Picked translation "$translationId" should be in active list');
    });
  });
}
