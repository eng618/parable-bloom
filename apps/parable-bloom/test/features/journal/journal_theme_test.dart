import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/features/journal/domain/entities/journal_theme.dart';

void main() {
  group('JournalTheme and JournalPassage Domain Entities', () {
    test('serializes and deserializes JournalTheme correctly', () {
      final jsonSample = {
        'id': 'growth',
        'name': 'Spiritual Growth',
        'description': 'Cultivating good soil in our hearts.',
        'icon': 'spa',
        'passages': [
          {
            'id': 'growth_seed_word',
            'title': 'The Seed is the Word',
            'reference': 'Luke 8:11',
            'type': 'starter',
            'trigger_level': 'lesson_5',
            'reflection_prompts': [
              'What kind of soil describes your heart right now?',
              'How can you make space for God\'s Word to take root?'
            ],
            'default_content':
                'Now the parable is this: The seed is the word of God.'
          }
        ]
      };

      final theme = JournalTheme.fromJson(jsonSample);

      expect(theme.id, equals('growth'));
      expect(theme.name, equals('Spiritual Growth'));
      expect(theme.icon, equals('spa'));
      expect(theme.passages.length, equals(1));

      final passage = theme.passages.first;
      expect(passage.id, equals('growth_seed_word'));
      expect(passage.themeId, equals('growth'));
      expect(passage.title, equals('The Seed is the Word'));
      expect(passage.reference, equals('Luke 8:11'));
      expect(passage.type, equals('starter'));
      expect(passage.triggerLevel, equals('lesson_5'));
      expect(passage.reflectionPrompts.length, equals(2));
      expect(passage.defaultContent,
          equals('Now the parable is this: The seed is the word of God.'));

      final reserialized = theme.toJson();
      expect(reserialized['id'], equals('growth'));
      expect((reserialized['passages'] as List).length, equals(1));
    });
  });

  group('biblical_themes.json Integrity', () {
    late Map<String, dynamic> themesData;
    late Map<String, dynamic> libraryData;

    setUpAll(() {
      final themesFile = File('assets/data/biblical_themes.json');
      themesData =
          json.decode(themesFile.readAsStringSync()) as Map<String, dynamic>;

      final libraryFile = File('assets/data/scripture_library.json');
      libraryData =
          json.decode(libraryFile.readAsStringSync()) as Map<String, dynamic>;
    });

    test('contains expected biblical themes', () {
      final themesList = themesData['themes'] as List<dynamic>;
      expect(themesList.isNotEmpty, isTrue);

      final themeIds = themesList.map((t) => t['id'] as String).toList();
      expect(themeIds,
          containsAll(['growth', 'faith', 'patience', 'love', 'joy']));
    });

    test(
        'all themes have valid metadata and reflection prompts for every passage',
        () {
      final passagesLibrary = libraryData['passages'] as Map<String, dynamic>;
      final themesList = themesData['themes'] as List<dynamic>;

      for (final rawTheme in themesList) {
        final theme = JournalTheme.fromJson(rawTheme as Map<String, dynamic>);
        expect(theme.id.isNotEmpty, isTrue,
            reason: 'Theme ID must not be empty');
        expect(theme.name.isNotEmpty, isTrue,
            reason: 'Theme name must not be empty');
        expect(theme.description.isNotEmpty, isTrue,
            reason: 'Theme description must not be empty');
        expect(theme.passages.isNotEmpty, isTrue,
            reason: 'Theme must have at least one passage');

        for (final passage in theme.passages) {
          expect(passage.id.isNotEmpty, isTrue,
              reason: 'Passage ID must not be empty');
          expect(passage.title.isNotEmpty, isTrue,
              reason: 'Passage title must not be empty');
          expect(passage.reference.isNotEmpty, isTrue,
              reason: 'Passage reference must not be empty');
          expect(passage.reflectionPrompts.length, greaterThanOrEqualTo(2),
              reason:
                  'Passage ${passage.id} must have at least 2 reflection prompts');

          // Ensure reference exists in scripture_library.json
          expect(passagesLibrary.containsKey(passage.reference), isTrue,
              reason:
                  'Passage reference "${passage.reference}" must exist in scripture_library.json');
        }
      }
    });
  });
}
