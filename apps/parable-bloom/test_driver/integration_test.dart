import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(onScreenshot: (name, image, [args]) async {
    final screenshotDir = Directory('build/integration_test_screenshots');
    if (!await screenshotDir.exists()) {
      await screenshotDir.create(recursive: true);
    }

    final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
    final file = File('${screenshotDir.path}/$safeName.png');
    await file.writeAsBytes(image);
    return true;
  });
}
