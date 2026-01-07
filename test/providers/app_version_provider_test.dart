import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parable_bloom/providers/game_providers.dart';

void main() {
  group('appVersionProvider', () {
    test('should provide version string', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Wait for the future to complete
      final version = await container.read(appVersionProvider.future);
      
      // Version should be a string
      expect(version, isA<String>());
      
      // Version should be in format "X.Y.Z+N" where X, Y, Z are numbers
      // and N is a build number
      expect(version, matches(RegExp(r'^\d+\.\d+\.\d+\+\d+$')));
    });

    test('version should not be empty', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final version = await container.read(appVersionProvider.future);
      
      expect(version, isNotEmpty);
    });
  });
}
