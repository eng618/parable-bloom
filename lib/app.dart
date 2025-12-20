import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/app_theme.dart';
import 'core/di/injection_container.dart' as di;
import 'features/game/presentation/screens/game_screen.dart';
import 'features/settings/presentation/screens/settings_screen.dart';

class ParableBloomApp extends ConsumerStatefulWidget {
  const ParableBloomApp({super.key});

  @override
  ConsumerState<ParableBloomApp> createState() => _ParableBloomAppState();
}

class _ParableBloomAppState extends ConsumerState<ParableBloomApp> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Initialize Hive
    final box = await Hive.openBox('garden_save');

    // Setup dependency injection
    await di.setupDependencies(box);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parable Bloom',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const GameScreen(),
      routes: {'/settings': (context) => const SettingsScreen()},
    );
  }
}
