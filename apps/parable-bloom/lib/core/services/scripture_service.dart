import 'dart:convert';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'logger_service.dart';

/// On-demand scripture resolver.
///
/// Bundle policy (keeps app size small):
/// - Only `bundled: true` translations ship in `scripture_library.json`
///   (NET default + KJV fallback).
/// - `onDemand: true` translations (WEB, BSB) are fetched once from
///   Firestore `scriptures/{ref}/translations/{id}`, cached in Hive
///   (`scriptureCache`), then work offline.
/// - Unknown/offline on-demand requests fall back to bundled text with
///   `didFallback=true` + `requiresDownload=true` so UI shows a banner.
class ScriptureService {
  Map<String, dynamic>? _scriptureLibrary;
  List<dynamic>? _translations;
  final Random _random = Random();
  final Map<String, String> _memoryCache = {};

  /// Injectable remote fetcher (Firestore in prod, stubbed in tests).
  /// Returns verse text or null when missing.
  Future<String?> Function(String reference, String translationId)?
      remoteFetcher;

  /// Connectivity override for tests.
  Future<bool> Function()? connectivityOverride;

  ScriptureService({this.remoteFetcher, this.connectivityOverride});

  /// Loads metadata and local scripture library files from assets.
  Future<void> initialize() async {
    try {
      if (_translations == null) {
        final metadataStr =
            await rootBundle.loadString('assets/data/scripture_metadata.json');
        final metadataJson = json.decode(metadataStr) as Map<String, dynamic>;
        _translations = metadataJson['translations'] as List<dynamic>;
        LoggerService.info(
            'Initialized scripture metadata with ${_translations?.length} translations.',
            tag: 'ScriptureService');
      }

      if (_scriptureLibrary == null) {
        final libraryStr =
            await rootBundle.loadString('assets/data/scripture_library.json');
        final libraryJson = json.decode(libraryStr) as Map<String, dynamic>;
        _scriptureLibrary = libraryJson['passages'] as Map<String, dynamic>;
        LoggerService.info('Initialized scripture library database.',
            tag: 'ScriptureService');
      }
    } catch (e, stack) {
      LoggerService.error('Failed to initialize ScriptureService',
          error: e, stackTrace: stack, tag: 'ScriptureService');
    }
  }

  List<Map<String, dynamic>> getActiveTranslations() {
    if (_translations == null) return [];
    return _translations!
        .where((t) => (t['status'] as String) == 'active')
        .map((t) => Map<String, dynamic>.from(t))
        .toList();
  }

  Map<String, dynamic>? getMetadata(String translationId) {
    if (_translations == null) return null;
    try {
      final found = _translations!.firstWhere(
        (t) => (t['id'] as String).toLowerCase() == translationId.toLowerCase(),
      );
      return Map<String, dynamic>.from(found);
    } catch (_) {
      return null;
    }
  }

  String getDefaultTranslationId() {
    if (_translations == null) return 'net';
    for (final t in _translations!) {
      if (t['isDefault'] == true && t['status'] == 'active') {
        return (t['id'] as String).toLowerCase();
      }
    }
    return 'net';
  }

  String getFallbackTranslationId() {
    if (_translations == null) return 'kjv';
    for (final t in _translations!) {
      if (t['isFallback'] == true && t['status'] == 'active') {
        return (t['id'] as String).toLowerCase();
      }
    }
    return 'kjv';
  }

  bool isTranslationBundled(String translationId) {
    return getMetadata(translationId)?['bundled'] == true;
  }

  bool isTranslationOnDemand(String translationId) {
    return getMetadata(translationId)?['onDemand'] == true;
  }

  /// Selects a random translation from the active translations pool.
  /// Kept for compatibility; new code should use the user's preferred id.
  Future<String> pickRandomActiveTranslation() async {
    await initialize();
    if (_translations == null || _translations!.isEmpty) {
      return getDefaultTranslationId();
    }

    final activeIds = <String>[];
    final isConnected = await _checkConnectivity();

    for (final translation in _translations!) {
      final id = (translation['id'] as String).toLowerCase();
      final status = translation['status'] as String;
      final requiresOnline = translation['requiresOnline'] as bool? ?? false;
      final onDemand = translation['onDemand'] as bool? ?? false;

      if (status == 'active') {
        // On-demand texts need connectivity unless already cached.
        if ((requiresOnline || onDemand) && !isConnected) continue;
        activeIds.add(id);
      }
    }

    if (activeIds.isEmpty) return getFallbackTranslationId();
    return activeIds[_random.nextInt(activeIds.length)];
  }

  /// Fetches a scripture text in the requested (or preferred) translation.
  ///
  /// Returns string map for caller compatibility:
  /// `{text, translation, didFallback: 'true'|'false',
  ///   fromCache: 'true'|'false', requiresDownload: 'true'|'false'}`.
  Future<Map<String, String>> loadScripture(String reference,
      {String? translationId, String? preferredTranslationId}) async {
    await initialize();

    final defaultId = getDefaultTranslationId();
    final fallbackId = getFallbackTranslationId();
    var targetId =
        (translationId ?? preferredTranslationId ?? defaultId).toLowerCase();

    // Unknown or inactive -> fall back to default.
    final meta = getMetadata(targetId);
    if (meta == null || meta['status'] != 'active') {
      targetId = defaultId;
    }

    try {
      // 1. Bundled local text (NET + KJV ship in the app bundle).
      final bundledText = _getBundledText(reference, targetId);
      if (bundledText != null) {
        return {
          'text': bundledText,
          'translation': targetId.toUpperCase(),
          'didFallback': 'false',
          'fromCache': 'false',
          'requiresDownload': 'false',
        };
      }

      // 2. Hive + memory cache (previously downloaded on-demand texts).
      final cached = _getCachedText(reference, targetId);
      if (cached != null) {
        return {
          'text': cached,
          'translation': targetId.toUpperCase(),
          'didFallback': 'false',
          'fromCache': 'true',
          'requiresDownload': 'false',
        };
      }

      // 3. On-demand remote fetch (Firestore) when online.
      final isOnDemand = isTranslationOnDemand(targetId);
      final requiresOnline =
          getMetadata(targetId)?['requiresOnline'] as bool? ?? false;
      final isConnected = await _checkConnectivity();
      if ((isOnDemand || requiresOnline) &&
          isConnected &&
          remoteFetcher != null) {
        try {
          final remoteText = await remoteFetcher!(reference, targetId);
          if (remoteText != null && remoteText.isNotEmpty) {
            await _putCachedText(reference, targetId, remoteText);
            return {
              'text': remoteText,
              'translation': targetId.toUpperCase(),
              'didFallback': 'false',
              'fromCache': 'false',
              'requiresDownload': 'false',
            };
          }
        } catch (e) {
          LoggerService.warn(
              'Remote scripture fetch failed for $reference ($targetId): $e',
              tag: 'ScriptureService');
        }
      }

      // 4. Fallback to bundled default, then hard fallback KJV.
      final needsDownload = (isOnDemand || requiresOnline) &&
          _getCachedText(reference, targetId) == null;
      final fallbackText = _getBundledText(reference, defaultId) ??
          _getBundledText(reference, fallbackId) ??
          _getLocalTextAndVersion(reference, 'KJV')['text']!;
      final fallbackVersion = _getBundledText(reference, defaultId) != null
          ? defaultId.toUpperCase()
          : fallbackId.toUpperCase();
      return {
        'text': fallbackText,
        'translation': fallbackVersion,
        'didFallback': 'true',
        'fromCache': 'false',
        'requiresDownload': needsDownload ? 'true' : 'false',
      };
    } catch (e) {
      LoggerService.warn(
          'Failed to fetch scripture $reference in $targetId. Falling back. Error: $e',
          tag: 'ScriptureService');
      final localResult = _getLocalTextAndVersion(reference, 'KJV');
      return {
        'text': localResult['text']!,
        'translation': 'KJV',
        'didFallback': 'true',
        'fromCache': 'false',
        'requiresDownload': 'false',
      };
    }
  }

  /// Pre-downloads [references] in [translationId] for offline use.
  /// Returns number of newly cached verses.
  Future<int> prefetchTranslations(
      List<String> references, String translationId) async {
    await initialize();
    if (remoteFetcher == null) return 0;
    if (!await _checkConnectivity()) return 0;
    var added = 0;
    for (final ref in references) {
      if (_getBundledText(ref, translationId) != null) continue;
      if (_getCachedText(ref, translationId) != null) continue;
      try {
        final text = await remoteFetcher!(ref, translationId);
        if (text != null && text.isNotEmpty) {
          await _putCachedText(ref, translationId, text);
          added++;
        }
      } catch (_) {
        // Best effort; stop silently on failure.
      }
    }
    return added;
  }

  /// All passage references known to the bundled library (for prefetch).
  List<String> get knownReferences {
    if (_scriptureLibrary == null) return [];
    return _scriptureLibrary!.keys.map((e) => e.toString()).toList();
  }

  String? _getBundledText(String reference, String translationId) {
    if (_scriptureLibrary == null) return null;
    // Only translations flagged bundled may come from the shipped JSON.
    // This keeps WEB/BSB out of the app bundle even if keys exist locally.
    if (!isTranslationBundled(translationId)) return null;
    final passage = _scriptureLibrary![reference] as Map<String, dynamic>?;
    if (passage == null) return null;
    final text = passage[translationId.toUpperCase()] as String?;
    if (text != null && text.isNotEmpty) return text;
    return null;
  }

  String _cacheKey(String reference, String translationId) =>
      '$reference|${translationId.toLowerCase()}';

  String? _getCachedText(String reference, String translationId) {
    final key = _cacheKey(reference, translationId);
    if (_memoryCache.containsKey(key)) return _memoryCache[key];
    try {
      if (Hive.isBoxOpen('garden_save')) {
        final box = Hive.box('garden_save');
        final raw = box.get('scriptureCache');
        if (raw is Map) {
          final text = raw[key] as String?;
          if (text != null && text.isNotEmpty) {
            _memoryCache[key] = text;
            return text;
          }
        }
      }
    } catch (_) {
      // Cache is best-effort; ignore errors.
    }
    return null;
  }

  Future<void> _putCachedText(
      String reference, String translationId, String text) async {
    final key = _cacheKey(reference, translationId);
    _memoryCache[key] = text;
    try {
      if (Hive.isBoxOpen('garden_save')) {
        final box = Hive.box('garden_save');
        final raw = box.get('scriptureCache');
        final map = raw is Map
            ? Map<String, dynamic>.from(
                raw.map((k, v) => MapEntry(k.toString(), v.toString())))
            : <String, dynamic>{};
        map[key] = text;
        await box.put('scriptureCache', map);
      }
    } catch (e) {
      LoggerService.warn('Failed to persist scripture cache: $e',
          tag: 'ScriptureService');
    }
  }

  Map<String, String> _getLocalTextAndVersion(
      String reference, String versionKey) {
    if (_scriptureLibrary == null) {
      return {
        'text': 'Scripture database not loaded.',
        'version': 'KJV',
      };
    }

    final passage = _scriptureLibrary![reference] as Map<String, dynamic>?;
    if (passage == null) {
      return {
        'text': "Passage '$reference' not found in offline library.",
        'version': 'KJV',
      };
    }

    final text = passage[versionKey] as String?;
    if (text != null && text.isNotEmpty) {
      return {
        'text': text,
        'version': versionKey,
      };
    }

    // Strict KJV fallback
    final fallbackText = passage['KJV'] as String?;
    if (fallbackText != null && fallbackText.isNotEmpty) {
      return {
        'text': fallbackText,
        'version': 'KJV',
      };
    }

    return {
      'text': "Scripture text not found for '$reference'.",
      'version': 'KJV',
    };
  }

  Future<bool> _checkConnectivity() async {
    if (connectivityOverride != null) {
      try {
        return await connectivityOverride!();
      } catch (_) {
        return false;
      }
    }
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }
}
