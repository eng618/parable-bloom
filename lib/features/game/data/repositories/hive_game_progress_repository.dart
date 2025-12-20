import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/entities/game_progress.dart';
import '../../domain/repositories/game_progress_repository.dart';

class HiveGameProgressRepository implements GameProgressRepository {
  final Box _box;

  HiveGameProgressRepository(this._box);

  @override
  Future<GameProgress> getProgress() async {
    final data = _box.get('progress');
    if (data != null) {
      return GameProgress.fromJson(Map<String, dynamic>.from(data));
    }
    return GameProgress.initial();
  }

  @override
  Future<void> saveProgress(GameProgress progress) async {
    await _box.put('progress', progress.toJson());
  }

  @override
  Future<void> resetProgress() async {
    await _box.put('progress', GameProgress.initial().toJson());
  }
}
