import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/di/injection_container.dart' as di;
import 'providers/game_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();
  final hiveBox = await Hive.openBox('garden_save');

  // Setup dependency injection
  await di.setupDependencies(hiveBox);

  runApp(
    ProviderScope(
      overrides: [hiveBoxProvider.overrideWithValue(hiveBox)],
      child: const ParableBloomApp(),
    ),
  );
}
