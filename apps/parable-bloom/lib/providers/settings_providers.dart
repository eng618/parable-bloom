import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/background_audio_controller.dart';
import 'infrastructure_providers.dart';

enum AppThemeMode { light, dark, system }

final boardZoomScaleProvider =
    AsyncNotifierProvider<BoardZoomScaleNotifier, double>(
  BoardZoomScaleNotifier.new,
);

class BoardZoomScaleNotifier extends AsyncNotifier<double> {
  @override
  Future<double> build() async {
    final repository = ref.watch(settingsRepositoryProvider);
    return repository.getBoardZoomScale();
  }

  Future<void> setScale(double scale) async {
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setBoardZoomScale(scale);
    state = AsyncValue.data(scale);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, AppThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() {
    final box = ref.watch(hiveBoxProvider);
    final value = box.get('themeMode', defaultValue: 'system');
    switch (value) {
      case 'light':
        return AppThemeMode.light;
      case 'dark':
        return AppThemeMode.dark;
      default:
        return AppThemeMode.system;
    }
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = mode;
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setThemeMode(mode.name);
  }
}

final backgroundAudioEnabledProvider =
    NotifierProvider<BackgroundAudioEnabledNotifier, bool>(
  BackgroundAudioEnabledNotifier.new,
);

class BackgroundAudioEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    final box = ref.watch(hiveBoxProvider);
    return box.get('backgroundAudioEnabled', defaultValue: true) as bool;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setBackgroundAudioEnabled(enabled);
  }
}

final useSimpleVinesProvider = NotifierProvider<UseSimpleVinesNotifier, bool>(
  UseSimpleVinesNotifier.new,
);

class UseSimpleVinesNotifier extends Notifier<bool> {
  @override
  bool build() {
    final box = ref.watch(hiveBoxProvider);
    return box.get('useSimpleVines', defaultValue: false) as bool;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setUseSimpleVines(enabled);
  }
}

final hapticsEnabledProvider = NotifierProvider<HapticsEnabledNotifier, bool>(
  HapticsEnabledNotifier.new,
);

class HapticsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    final box = ref.watch(hiveBoxProvider);
    return box.get('hapticsEnabled', defaultValue: true) as bool;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setHapticsEnabled(enabled);
  }
}

final backgroundAudioControllerProvider = Provider<BackgroundAudioController>((
  ref,
) {
  final controller = BackgroundAudioController();

  ref.onDispose(() {
    unawaited(controller.dispose());
  });

  ref.listen<bool>(backgroundAudioEnabledProvider, (previous, next) {
    unawaited(controller.setEnabled(next));
  });

  unawaited(controller.setEnabled(ref.read(backgroundAudioEnabledProvider)));

  return controller;
});

final debugShowGridCoordinatesProvider =
    NotifierProvider<DebugShowGridCoordinatesNotifier, bool>(
  DebugShowGridCoordinatesNotifier.new,
);

class DebugShowGridCoordinatesNotifier extends Notifier<bool> {
  @override
  bool build() {
    final box = ref.watch(hiveBoxProvider);
    return box.get('debugShowGridCoordinates', defaultValue: false) as bool;
  }

  Future<void> setShowCoordinates(bool show) async {
    state = show;
    final box = ref.read(hiveBoxProvider);
    await box.put('debugShowGridCoordinates', show);
  }
}

final debugVineAnimationLoggingProvider =
    NotifierProvider<DebugVineAnimationLoggingNotifier, bool>(
  DebugVineAnimationLoggingNotifier.new,
);

final debugUiEnabledForTestsProvider = Provider<bool>((ref) => false);

class DebugVineAnimationLoggingNotifier extends Notifier<bool> {
  @override
  bool build() {
    final box = ref.watch(hiveBoxProvider);
    return box.get('debugVineAnimationLogging', defaultValue: false) as bool;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final box = ref.read(hiveBoxProvider);
    await box.put('debugVineAnimationLogging', enabled);
  }
}
