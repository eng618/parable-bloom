import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/providers/game_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ModuleData loads correctly from modules.json', () async {
    final jsonString = await rootBundle.loadString('assets/data/modules.json');
    final jsonMap = json.decode(jsonString);
    final modulesList = jsonMap['modules'] as List<dynamic>;

    expect(modulesList.isNotEmpty, true, reason: 'Should have at least one module');

    final firstModule = ModuleData.fromJson(modulesList[0] as Map<String, dynamic>);

    print('Module: ${firstModule.name}');
    print('Start level: ${firstModule.startLevel}');
    print('End level: ${firstModule.endLevel}');
    print('Level count: ${firstModule.levelCount}');
    print('Levels: ${firstModule.levels}');

    expect(firstModule.name, 'Seedling');
    expect(firstModule.startLevel, 11, reason: 'Start level should be 11');
    expect(firstModule.endLevel, 54, reason: 'End level should be 54 (max from levels array)');
    expect(firstModule.levelCount, 44, reason: 'Should have 44 levels (11-54)');
    expect(firstModule.containsLevel(11), true);
    expect(firstModule.containsLevel(54), true);
    expect(firstModule.containsLevel(10), false);
    expect(firstModule.containsLevel(55), false);
  });
}
