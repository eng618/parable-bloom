import 'package:hive_flutter/hive_flutter.dart';

/// Repository for managing the current global level using Hive.
/// This stores the player's progress across the entire game.
class HiveGlobalLevelRepository {
  final Box _box;

  static const String _currentLevelKey = 'current_global_level';
  static const int _defaultLevel = 1;

  HiveGlobalLevelRepository(this._box);

  /// Gets the current global level.
  /// Returns default level 1 if not set.
  Future<int> getCurrentGlobalLevel() async {
    final level = _box.get(_currentLevelKey, defaultValue: _defaultLevel);
    return level as int;
  }

  /// Sets the current global level.
  Future<void> setCurrentGlobalLevel(int level) async {
    await _box.put(_currentLevelKey, level);
  }
}
