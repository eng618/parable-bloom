import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/core/config/environment_config.dart';

void main() {
  group('EnvironmentConfig', () {
    test('defaults to dev environment', () {
      expect(EnvironmentConfig.isDev(), true);
      expect(EnvironmentConfig.isPreview(), false);
      expect(EnvironmentConfig.isProd(), false);
    });

    test('returns correct Firestore collection for dev', () {
      // Note: This test always runs in dev environment since APP_ENV is not set
      expect(EnvironmentConfig.getFirestoreCollection(), 'game_progress_dev');
    });

    test('returns human-readable environment name', () {
      expect(EnvironmentConfig.environmentName(), 'Development');
    });

    test('distinguishes production from non-production', () {
      expect(EnvironmentConfig.isProd(), false);
      expect(!EnvironmentConfig.isProd(), true);
    });

    test('collection name follows pattern game_progress_{env}', () {
      final collection = EnvironmentConfig.getFirestoreCollection();
      expect(collection.startsWith('game_progress_'), true);
    });
  });
}
