import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/environment_config.dart';
import '../services/analytics_service.dart';
import '../services/scripture_service.dart';
import 'infrastructure_providers.dart';

String encodeScriptureDocId(String reference) =>
    Uri.encodeComponent(reference).replaceAll('/', '_');

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});

final scriptureServiceProvider = Provider<ScriptureService>((ref) {
  final service = ScriptureService();
  // Wire Firestore on-demand fetcher lazily; failures fall back to bundle.
  service.remoteFetcher = (reference, translationId) async {
    try {
      final firestore = ref.read(firestoreProvider);
      final docId = encodeScriptureDocId(reference);
      final doc = await firestore
          .collection(EnvironmentConfig.getScripturesCollection())
          .doc(docId)
          .collection('translations')
          .doc(translationId.toLowerCase())
          .get();
      final text = doc.data()?['text'] as String?;
      return text;
    } catch (_) {
      return null;
    }
  };
  return service;
});

final appVersionProvider = FutureProvider<String>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  return '${packageInfo.version}+${packageInfo.buildNumber}';
});

/// Active scripture translations for the picker + attributions screens.
final activeTranslationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(scriptureServiceProvider);
  await service.initialize();
  return service.getActiveTranslations();
});
