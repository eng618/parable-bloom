import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/analytics_service.dart';

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  throw UnimplementedError('AnalyticsService must be initialized in main');
});

final appVersionProvider = FutureProvider<String>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  return '${packageInfo.version}+${packageInfo.buildNumber}';
});
