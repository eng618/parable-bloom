import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'logger_service.dart';

class ScriptureService {
  Map<String, dynamic>? _scriptureLibrary;
  List<dynamic>? _translations;
  final Random _random = Random();

  ScriptureService();

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

  /// Selects a random translation from the active translations pool.
  /// Standard KJV and WEB are always active, NET is active (under gratis terms).
  /// ESV and CSB are active (if online).
  /// NIV and NLT are excluded (pending commercial licensing).
  Future<String> pickRandomActiveTranslation() async {
    await initialize();
    if (_translations == null || _translations!.isEmpty) return 'kjv';

    final activeIds = <String>[];
    final isConnected = await _checkConnectivity();

    for (final translation in _translations!) {
      final id = (translation['id'] as String).toLowerCase();
      final status = translation['status'] as String;
      final requiresOnline = translation['requiresOnline'] as bool;

      if (status == 'active') {
        if (!requiresOnline || isConnected) {
          activeIds.add(id);
        }
      }
    }

    if (activeIds.isEmpty) return 'kjv';
    return activeIds[_random.nextInt(activeIds.length)];
  }

  /// Fetches a scripture text, falling back to KJV if it is online-only and we are offline, or if retrieval fails.
  /// Returns a map containing the loaded text and the selected translation abbreviation.
  Future<Map<String, String>> loadScripture(String reference,
      {String? translationId}) async {
    await initialize();

    // 1. Pick a random translation if none is specified
    final targetId = translationId ?? await pickRandomActiveTranslation();

    // 2. Fetch the text
    String text = '';
    String finalId = targetId;

    try {
      final isOnlineOnly = _isTranslationOnlineOnly(targetId);
      final isConnected = await _checkConnectivity();

      if (isOnlineOnly && isConnected) {
        // Fetch from API.Bible (online)
        // For now, since API.Bible client is not yet fully configured, we simulate API load or fallback to local
        // Once the API client is fully integrated, this will fetch remote text.
        // For now we fall back to local KJV (which is what we have for now).
        final localResult = _getLocalTextAndVersion(reference, 'KJV');
        text = localResult['text']!;
        finalId =
            'kjv'; // Fallback to KJV for now since online API isn't built yet
        LoggerService.info(
            'Fetched scripture $reference in $targetId (simulated online fetch fallback to local KJV)',
            tag: 'ScriptureService');
      } else {
        // Load local translation
        final localResult =
            _getLocalTextAndVersion(reference, targetId.toUpperCase());
        text = localResult['text']!;
        finalId = localResult['version']!.toLowerCase();
      }
    } catch (e) {
      LoggerService.warn(
          'Failed to fetch scripture $reference in $targetId. Falling back to KJV. Error: $e',
          tag: 'ScriptureService');
      final localResult = _getLocalTextAndVersion(reference, 'KJV');
      text = localResult['text']!;
      finalId = 'kjv';
    }

    return {
      'text': text,
      'translation': finalId.toUpperCase(),
    };
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

  bool _isTranslationOnlineOnly(String translationId) {
    if (_translations == null) return false;
    final trans = _translations!.firstWhere(
      (element) =>
          (element['id'] as String).toLowerCase() ==
          translationId.toLowerCase(),
      orElse: () => null,
    );
    return trans != null ? (trans['requiresOnline'] as bool) : false;
  }

  Future<bool> _checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }
}
