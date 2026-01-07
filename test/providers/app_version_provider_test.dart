import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parable_bloom/providers/game_providers.dart';

void main() {
  group('appVersionProvider', () {
    test('should provide version string', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final versionAsync = container.read(appVersionProvider);
      
      // The provider should eventually provide a version string
      await expectLater(
        versionAsync.future,
        completion(isA<String>()),
      );
      
      final version = await versionAsync.future;
      
      // Version should be in format "X.Y.Z+N" where X, Y, Z are numbers
      // and N is a build number
      expect(version, matches(RegExp(r'^\d+\.\d+\.\d+\+\d+$')));
    });

    test('version should not be empty', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final versionAsync = container.read(appVersionProvider);
      final version = await versionAsync.future;
      
      expect(version, isNotEmpty);
    });
  });
}
