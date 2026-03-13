import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/logger_service.dart';
import '../../domain/entities/level_data.dart';

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
