import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/repositories/global_level_repository.dart';

/// Hive-based implementation of GlobalLevelRepository.
/// Stores the current global level locally using Hive.
class HiveGlobalLevelRepository implements GlobalLevelRepository {
  final Box hiveBox;
  static const String _currentGlobalLevelKey = 'currentGlobalLevel';
  static const int _defaultLevel = 1;

  HiveGlobalLevelRepository(this.hiveBox);

  @override
  Future<int> getCurrentGlobalLevel() async {
    return hiveBox.get(_currentGlobalLevelKey, defaultValue: _defaultLevel)
        as int;
  }

  @override
  Future<void> setCurrentGlobalLevel(int level) async {
    await hiveBox.put(_currentGlobalLevelKey, level);
  }
}
