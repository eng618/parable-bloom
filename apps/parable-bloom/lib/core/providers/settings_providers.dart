import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/environment_config.dart';
import '../services/background_audio_controller.dart';
import 'infrastructure_providers.dart';
import 'service_providers.dart';

/// Firestore collection for settings (mirrors game-progress env isolation).
final settingsCollectionProvider = Provider<String>((ref) {
  return EnvironmentConfig.getFirestoreCollection();
});

SetOptions optionsSetMerge() => SetOptions(merge: true);

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

enum VineStyle {
  classic,
  blossom,
  ethereal,
  simple,
}

final vineStyleProvider = NotifierProvider<VineStyleNotifier, VineStyle>(
  VineStyleNotifier.new,
);

class VineStyleNotifier extends Notifier<VineStyle> {
  @override
  VineStyle build() {
    final box = ref.watch(hiveBoxProvider);

    // Support migration from old boolean 'useSimpleVines'
    final oldUseSimpleVines = box.get('useSimpleVines');
    if (oldUseSimpleVines != null) {
      final style =
          (oldUseSimpleVines as bool) ? VineStyle.simple : VineStyle.classic;
      box.put('vineStyle', style.name);
      box.delete('useSimpleVines');
      return style;
    }

    final value = box.get('vineStyle', defaultValue: 'classic') as String;
    return VineStyle.values.firstWhere(
      (e) => e.name == value,
      orElse: () => VineStyle.classic,
    );
  }

  Future<void> setStyle(VineStyle style) async {
    state = style;
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setVineStyle(style.name);
  }
}

final useSimpleVinesProvider = NotifierProvider<UseSimpleVinesNotifier, bool>(
  UseSimpleVinesNotifier.new,
);

class UseSimpleVinesNotifier extends Notifier<bool> {
  @override
  bool build() {
    final style = ref.watch(vineStyleProvider);
    return style == VineStyle.simple;
  }

  Future<void> setEnabled(bool enabled) async {
    final style = enabled ? VineStyle.simple : VineStyle.classic;
    await ref.read(vineStyleProvider.notifier).setStyle(style);
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

final analyticsEnabledProvider =
    NotifierProvider<AnalyticsEnabledNotifier, bool>(
  AnalyticsEnabledNotifier.new,
);

class AnalyticsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    final box = ref.watch(hiveBoxProvider);
    final isIgnored = box.get('openpanel_ignore', defaultValue: false) as bool;
    return !isIgnored;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final box = ref.read(hiveBoxProvider);
    await box.put('openpanel_ignore', !enabled);

    final analyticsService = ref.read(analyticsServiceProvider);
    await analyticsService.setCollectionEnabled(enabled);
  }
}

/// Preferred Bible translation id (e.g. 'net').
/// Offline-first in Hive; best-effort cloud sync to Firestore settings doc
/// when a non-anonymous user is signed in.
final preferredTranslationProvider =
    NotifierProvider<PreferredTranslationNotifier, String>(
  PreferredTranslationNotifier.new,
);

class PreferredTranslationNotifier extends Notifier<String> {
  static const String _defaultId = 'net';

  @override
  String build() {
    final box = ref.watch(hiveBoxProvider);
    final value =
        box.get('preferredTranslationId', defaultValue: _defaultId) as String?;
    return (value ?? _defaultId).toLowerCase();
  }

  Future<void> setPreferred(String translationId) async {
    final normalized = translationId.toLowerCase();
    state = normalized;
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setPreferredTranslation(normalized);
    // Best-effort cloud sync; never throws to callers.
    await syncToCloud();
  }

  Future<void> syncToCloud() async {
    try {
      final auth = ref.read(firebaseAuthProvider);
      final user = auth.currentUser;
      if (user == null || user.isAnonymous) return;
      final firestore = ref.read(firestoreProvider);
      final collection = ref.read(settingsCollectionProvider);
      await firestore
          .collection(collection)
          .doc(user.uid)
          .collection('data')
          .doc('settings')
          .set({
        'preferredTranslationId': state,
        'lastUpdated': DateTime.now().toIso8601String(),
      }, optionsSetMerge());
    } catch (_) {
      // Offline or unavailable: local Hive remains source of truth.
    }
  }

  Future<void> syncFromCloud() async {
    try {
      final auth = ref.read(firebaseAuthProvider);
      final user = auth.currentUser;
      if (user == null || user.isAnonymous) return;
      final firestore = ref.read(firestoreProvider);
      final collection = ref.read(settingsCollectionProvider);
      final doc = await firestore
          .collection(collection)
          .doc(user.uid)
          .collection('data')
          .doc('settings')
          .get();
      final remoteId =
          (doc.data()?['preferredTranslationId'] as String?)?.toLowerCase();
      if (remoteId != null && remoteId.isNotEmpty && remoteId != state) {
        state = remoteId;
        final repository = ref.read(settingsRepositoryProvider);
        await repository.setPreferredTranslation(remoteId);
      }
    } catch (_) {
      // Keep local value on failure.
    }
  }
}
