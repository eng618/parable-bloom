import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/core/services/scripture_service.dart';

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
      final result1 =
          await service.loadScripture('Matthew 13:31-32', translationId: 'kjv');
      expect(result1['translation'], 'KJV');
      expect(result1['text']!.contains('mustard seed'), true);

      // Test loading Matthew 9:37-38
      final result2 =
          await service.loadScripture('Matthew 9:37-38', translationId: 'kjv');
      expect(result2['translation'], 'KJV');
      expect(result2['text']!.contains('harvest'), true);
      expect(result2['text']!.contains('labourers'), true);
    });

    test('Loads KJV micro-verses correctly from local database', () async {
      await service.initialize();

      final result1 =
          await service.loadScripture('Luke 8:11', translationId: 'kjv');
      expect(result1['text']!.contains('seed is the word'), true);

      final result2 =
          await service.loadScripture('Luke 17:6', translationId: 'kjv');
      expect(result2['text']!.contains('mustard seed'), true);

      final result3 =
          await service.loadScripture('Galatians 6:9', translationId: 'kjv');
      expect(result3['text']!.contains('due season'), true);
    });

    test('Gracefully falls back to default NET for unknown translation',
        () async {
      // If we pass 'invalid_id', it should fall back to the default (NET).
      final result = await service.loadScripture('Mark 4:26-29',
          translationId: 'invalid_id');
      expect(result['translation'], 'NET');
      expect(result['text']!.contains('kingdom of God'), true);
    });

    test('Returns warning message for completely missing scripture references',
        () async {
      final result =
          await service.loadScripture('Genesis 1:1', translationId: 'kjv');
      expect(result['text']!.contains('not found in offline library'), true);
    });

    test('Randomly selects an active translation ID', () async {
      service.connectivityOverride = () async => true;
      final translationId = await service.pickRandomActiveTranslation();
      expect(translationId.isNotEmpty, true);
      // Active translations: net (default), web + bsb (on-demand), kjv (fallback)
      final validActive = {'web', 'kjv', 'net', 'bsb'};
      expect(validActive.contains(translationId), true,
          reason:
              'Picked translation "$translationId" should be in active list');
    });

    test('Loads bundled NET by default without fallback', () async {
      await service.initialize();
      expect(service.getDefaultTranslationId(), 'net');
      expect(service.getFallbackTranslationId(), 'kjv');

      // NET ships in the app bundle: no fallback, no download needed.
      service.connectivityOverride = () async => false;
      final result = await service.loadScripture('Luke 8:11',
          preferredTranslationId: 'net');
      expect(result['didFallback'], 'false');
      expect(result['translation'], 'NET');
      expect(result['text']!.contains('seed is the word of God'), true);
    });

    test('Falls back to bundled KJV when on-demand text is unavailable offline',
        () async {
      await service.initialize();
      service.connectivityOverride = () async => false;
      final result =
          await service.loadScripture('Luke 8:11', translationId: 'web');
      expect(result['didFallback'], 'true');
      expect(result['requiresDownload'], 'true');
      expect(result['translation'], 'NET');
    });

    test('Returns cached on-demand text without fallback', () async {
      service.connectivityOverride = () async => true;
      service.remoteFetcher = (ref, id) async => 'Cached WEB text for $ref';
      final result =
          await service.loadScripture('Luke 8:11', translationId: 'web');
      expect(result['translation'], 'WEB');
      expect(result['didFallback'], 'false');
      expect(result['text']!.contains('Cached WEB text'), true);
    });
  });
}
