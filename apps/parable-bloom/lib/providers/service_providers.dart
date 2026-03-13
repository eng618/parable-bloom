import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../features/game/domain/entities/level_data.dart';
import '../features/game/domain/services/level_solver_service.dart';
import '../services/analytics_service.dart';
import '../services/logger_service.dart';

final modulesProvider = FutureProvider<List<ModuleData>>((ref) async {
  try {
    final jsonString = await rootBundle.loadString(
      'assets/data/modules.json',
    );
    final jsonMap = json.decode(jsonString);
    final modulesList = jsonMap['modules'] as List<dynamic>;

    return modulesList
        .map((moduleJson) =>
            ModuleData.fromJson(moduleJson as Map<String, dynamic>))
        .toList();
  } catch (e, stack) {
    LoggerService.error('Error loading modules.json',
        error: e, stackTrace: stack, tag: 'modulesProvider');
    return [];
  }
});

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  throw UnimplementedError('AnalyticsService must be initialized in main');
});

final appVersionProvider = FutureProvider<String>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  return '${packageInfo.version}+${packageInfo.buildNumber}';
});

final levelSolverServiceProvider = Provider<LevelSolverService>((ref) {
  return LevelSolverService();
});