import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/entities/level.dart';
import '../../domain/repositories/level_repository.dart';
import '../models/level_model.dart';

class AssetLevelRepository implements LevelRepository {
  final String levelsPath;

  AssetLevelRepository({this.levelsPath = 'assets/levels'});

  @override
  Future<Level?> getLevel(int levelNumber) async {
    try {
      final levelJson = await rootBundle.loadString(
        '$levelsPath/level_$levelNumber.json',
      );
      final jsonMap = json.decode(levelJson);
      final levelModel = LevelModel.fromJson(jsonMap);
      return levelModel.toDomain();
    } catch (e) {
      // Level doesn't exist or failed to load
      return null;
    }
  }

  @override
  Future<List<int>> getAvailableLevelNumbers() async {
    // For now, we'll check levels 1-10 as that's what the current assets have
    // In a production app, this would scan the assets directory
    final availableLevels = <int>[];

    for (int i = 1; i <= 10; i++) {
      try {
        await rootBundle.loadString('$levelsPath/level_$i.json');
        availableLevels.add(i);
      } catch (e) {
        // Level doesn't exist, stop checking
        break;
      }
    }

    return availableLevels;
  }

  @override
  Future<bool> levelExists(int levelNumber) async {
    try {
      await rootBundle.loadString('$levelsPath/level_$levelNumber.json');
      return true;
    } catch (e) {
      return false;
    }
  }
}
