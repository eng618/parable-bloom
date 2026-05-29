import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/features/game/domain/entities/level_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ModuleData loads correctly from modules.json', () async {
    final jsonString = await rootBundle.loadString('assets/data/modules.json');
    final jsonMap = json.decode(jsonString);
    final modulesList = jsonMap['modules'] as List<dynamic>;

    expect(modulesList.isNotEmpty, true,
        reason: 'Should have at least one module');

    final firstModule =
        ModuleData.fromJson(modulesList[0] as Map<String, dynamic>);

    print('Module: ${firstModule.name}');
    print('Start level: ${firstModule.startLevel}');
    print('End level: ${firstModule.endLevel}');
    print('Level count: ${firstModule.levelCount}');
    print('Levels: ${firstModule.levels}');

    expect(firstModule.name, 'Seedling');
    expect(firstModule.startLevel, 'lvl_seed_01', reason: 'Start level should be lvl_seed_01');
    expect(firstModule.endLevel, 'lvl_seed_challenge',
        reason: 'End level should be lvl_seed_challenge');
    expect(firstModule.levelCount, 21, reason: 'Should have 21 levels');
    expect(firstModule.containsLevel('lvl_seed_01'), true);
    expect(firstModule.containsLevel('lvl_seed_challenge'), true);
    expect(firstModule.containsLevel('lesson_1'), false);
    expect(firstModule.containsLevel('lvl_sprout_01'), false);
  });
}
