import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parable_bloom/providers/game_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('appVersionProvider', () {
    setUp(() {
      // Mock the method channel for package_info_plus
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/package_info'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'getAll') {
            return <String, dynamic>{
              'appName': 'parable_bloom',
              'packageName': 'com.example.parable_bloom',
              'version': '1.1.6',
              'buildNumber': '1',
            };
          }
          return null;
        },
      );
    });

    tearDown(() {
      // Clean up the mock
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/package_info'),
        null,
      );
    });

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

    test('version format matches mocked value', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final version = await container.read(appVersionProvider.future);

      // Should return the mocked version
      expect(version, '1.1.6+1');
    });
  });
}
