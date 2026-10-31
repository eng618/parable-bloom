import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/environment_config.dart';
import '../services/background_audio_controller.dart';
import '../services/sfx_controller.dart';
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

final sfxEnabledProvider = NotifierProvider<SfxEnabledNotifier, bool>(
  SfxEnabledNotifier.new,
);

/// Feature flag: textured vine skins (classic / blossom / ethereal) behind
/// [vineTexturedSkinsEnabled]. When disabled only the flat/simple style is
/// available so textured rendering stays a development-only option.
final vineTexturedSkinsEnabledProvider =
    NotifierProvider<VineTexturedSkinsEnabledNotifier, bool>(
  VineTexturedSkinsEnabledNotifier.new,
);

class VineTexturedSkinsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    final box = ref.watch(hiveBoxProvider);
    return box.get('vineTexturedSkins', defaultValue: false) as bool;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final box = ref.read(hiveBoxProvider);
    await box.put('vineTexturedSkins', enabled);

    // When disabling, force the active style back to simple so no textured
    // vine leaks through while the flag is off.
    if (!enabled) {
      final style = ref.read(vineStyleProvider);
      if (style != VineStyle.simple) {
        await ref.read(vineStyleProvider.notifier).setStyle(VineStyle.simple);
      }
    }
  }
}

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

class SfxEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    final box = ref.watch(hiveBoxProvider);
    return box.get('sfxEnabled', defaultValue: true) as bool;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setSfxEnabled(enabled);
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
    final texturedEnabled = ref.watch(vineTexturedSkinsEnabledProvider);
    final box = ref.watch(hiveBoxProvider);

    // Support migration from old boolean 'useSimpleVines'
    final oldUseSimpleVines = box.get('useSimpleVines');
    if (oldUseSimpleVines != null) {
      final style =
          (oldUseSimpleVines as bool) ? VineStyle.simple : VineStyle.classic;
      box.put('vineStyle', style.name);
      box.delete('useSimpleVines');
      return texturedEnabled ? style : VineStyle.simple;
    }

    final value = box.get('vineStyle', defaultValue: 'classic') as String;
    final parsed = VineStyle.values.firstWhere(
      (e) => e.name == value,
      orElse: () => VineStyle.classic,
    );

    // Textured skins are behind a feature flag: when disabled, only the flat
    // simple style is available. A saved non-simple style silently degrades
    // to simple rather than rendering a disabled texture.
    if (!texturedEnabled && parsed != VineStyle.simple) {
      return VineStyle.simple;
    }
    return parsed;
  }

  Future<void> setStyle(VineStyle style) async {
    final texturedEnabled = ref.read(vineTexturedSkinsEnabledProvider);
    if (!texturedEnabled && style != VineStyle.simple) {
      // Textured skins are behind a feature flag: refuse to switch to a
      // disabled texture and stay on simple instead.
      style = VineStyle.simple;
    }
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
    final texturedEnabled = ref.read(vineTexturedSkinsEnabledProvider);
    // When textured skins are disabled, simple is always on; the toggle is
    // a no-op.
    if (!texturedEnabled) return;
    // Never clobber a non-simple style: disabling the toggle only restores
    // classic when simple mode is actually active.
    if (!enabled && ref.read(vineStyleProvider) != VineStyle.simple) return;
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

final sfxControllerProvider = Provider<SfxController>((ref) {
  final controller = SfxController();

  ref.onDispose(() {
    unawaited(controller.dispose());
  });

  ref.listen<bool>(sfxEnabledProvider, (previous, next) {
    unawaited(controller.setEnabled(next));
  });

  unawaited(controller.setEnabled(ref.read(sfxEnabledProvider)));
  unawaited(controller.ensureLoaded());

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

/// Which vine renderer runs. `rail` is the new track/window/vertex-strip
/// renderer; `legacy` keeps the per-frame Path painter for A/B regression.
final vineRenderModeProvider =
    NotifierProvider<VineRenderModeNotifier, VineRenderMode>(
  VineRenderModeNotifier.new,
);

enum VineRenderMode { rail, legacy }

class VineRenderModeNotifier extends Notifier<VineRenderMode> {
  @override
  VineRenderMode build() {
    final box = ref.watch(hiveBoxProvider);
    final value = box.get('vineRenderMode', defaultValue: 'rail') as String;
    return VineRenderMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => VineRenderMode.rail,
    );
  }

  Future<void> setMode(VineRenderMode mode) async {
    state = mode;
    final box = ref.read(hiveBoxProvider);
    await box.put('vineRenderMode', mode.name);
  }
}

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
