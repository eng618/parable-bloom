import 'dart:core';

class MockLevelData {
  final String difficulty;
  MockLevelData(this.difficulty);
}

// Mocking ref.read(levelDataProvider(lvl).future)
Future<MockLevelData> fetchLevelData(String lvl) async {
  // Simulate network/db delay
  await Future.delayed(Duration(milliseconds: 50));
  if (lvl == 'error') throw Exception('error');
  return MockLevelData('Medium');
}

Future<Map<String, String>> loadLabelsSequential(List<String> levels) async {
  final labels = <String, String>{};
  for (final lvl in levels) {
    try {
      final levelData = await fetchLevelData(lvl);
      final difficulty = levelData.difficulty;
      final index = levels.indexOf(lvl) + 1;
      labels[lvl] = 'Level $index ($lvl) — $difficulty';
    } catch (_) {
      labels[lvl] = lvl;
    }
  }
  return labels;
}

Future<Map<String, String>> loadLabelsConcurrent(List<String> levels) async {
  final labels = <String, String>{};
  final futures = levels.asMap().entries.map((entry) async {
    final index = entry.key + 1;
    final lvl = entry.value;
    try {
      final levelData = await fetchLevelData(lvl);
      final difficulty = levelData.difficulty;
      return MapEntry(lvl, 'Level $index ($lvl) — $difficulty');
    } catch (_) {
      return MapEntry(lvl, lvl);
    }
  });

  final results = await Future.wait(futures);
  for (final result in results) {
    labels[result.key] = result.value;
  }
  return labels;
}

void main() async {
  final levels = List.generate(50, (i) => 'level_$i');

  print('Warming up...');
  await loadLabelsSequential(levels.take(5).toList());
  await loadLabelsConcurrent(levels.take(5).toList());

  print('Running sequential...');
  final seqStart = DateTime.now();
  await loadLabelsSequential(levels);
  final seqEnd = DateTime.now();
  final seqDuration = seqEnd.difference(seqStart);
  print('Sequential time: ' + seqDuration.inMilliseconds.toString() + ' ms');

  print('Running concurrent...');
  final concStart = DateTime.now();
  await loadLabelsConcurrent(levels);
  final concEnd = DateTime.now();
  final concDuration = concEnd.difference(concStart);
  print('Concurrent time: ' + concDuration.inMilliseconds.toString() + ' ms');

  print('Improvement: ' + (seqDuration.inMilliseconds / concDuration.inMilliseconds).toStringAsFixed(2) + 'x faster');
}
