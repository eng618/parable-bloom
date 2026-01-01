import 'dart:convert';
import 'dart:io';
import 'dart:math';

void main(List<String> args) {
  final parsed = _parseArgs(args);

  final outDir = Directory(parsed.outDir);
  if (!outDir.existsSync()) {
    stderr.writeln('Output directory not found: ${outDir.path}');
    exitCode = 2;
    return;
  }

  final startId = parsed.startId ?? (_detectNextLevelId(outDir) ?? 1);
  final endId = startId + parsed.count - 1;

  for (int levelId = startId; levelId <= endId; levelId++) {
    final file = File('${outDir.path}/level_$levelId.json');
    if (file.existsSync() && !parsed.overwrite) {
      stderr.writeln(
        'Refusing to overwrite existing file: ${file.path} (pass --overwrite)',
      );
      exitCode = 2;
      return;
    }

    final levelJson = _generateLevel(levelId);
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(levelJson)}\n',
    );
    stdout.writeln('Wrote ${file.path}');
  }
}

Map<String, dynamic> _generateLevel(int levelId) {
  final (gridWidth, gridHeight) = _gridSizeFor(levelId);

  final rng = Random(levelId);

  final vines = <Map<String, dynamic>>[];
  final occupied = <String>{};

  final desiredVines = (6 + (levelId ~/ 6)).clamp(6, 18);
  for (int i = 0; i < desiredVines; i++) {
    final vine = _tryGenerateWindingVine(
      vineIndex: i,
      gridWidth: gridWidth,
      gridHeight: gridHeight,
      occupied: occupied,
      rng: rng,
    );
    if (vine == null) break;
    vines.add(vine);
  }

  // Ensure there's at least one vine; if winding generation fails entirely,
  // fall back to a single simple vine.
  if (vines.isEmpty) {
    final y = (gridHeight / 2).floor();
    final head = {'x': 0, 'y': y};
    final neck = {'x': 1, 'y': y};
    vines.add({
      'id': 'vine_1',
      'head_direction': 'left',
      'ordered_path': [head, neck],
      'vine_color': 'default',
    });
  }

  return {
    'id': levelId,
    'name': 'Level $levelId',
    'difficulty': 'Seedling',
    'grid_size': [gridWidth, gridHeight],
    'mask': {'mode': 'show-all', 'points': []},
    'vines': vines,
    'max_moves': vines.length,
    'min_moves': 0,
    'complexity': 'low',
    'grace': 3,
  };
}

Map<String, dynamic>? _tryGenerateWindingVine({
  required int vineIndex,
  required int gridWidth,
  required int gridHeight,
  required Set<String> occupied,
  required Random rng,
}) {
  // Always place the head on a boundary and point outward.
  // This keeps generated levels solver-friendly while still allowing winding bodies.
  const boundarySides = ['left', 'right', 'bottom', 'top'];

  final targetLen = (3 + rng.nextInt(6)).clamp(2, 10);

  for (int attempt = 0; attempt < 80; attempt++) {
    final side = boundarySides[rng.nextInt(boundarySides.length)];

    final (headX, headY, headDir) = switch (side) {
      'left' => (0, rng.nextInt(gridHeight), 'left'),
      'right' => (gridWidth - 1, rng.nextInt(gridHeight), 'right'),
      'bottom' => (rng.nextInt(gridWidth), 0, 'down'),
      _ => (rng.nextInt(gridWidth), gridHeight - 1, 'up'),
    };

    final (dx, dy) = switch (headDir) {
      'left' => (-1, 0),
      'right' => (1, 0),
      'up' => (0, 1),
      _ => (0, -1),
    };

    // Neck must be exactly one cell opposite head_direction.
    final neckX = headX - dx;
    final neckY = headY - dy;
    if (neckX < 0 || neckX >= gridWidth || neckY < 0 || neckY >= gridHeight) {
      continue;
    }

    final headKey = '$headX,$headY';
    final neckKey = '$neckX,$neckY';
    if (occupied.contains(headKey) || occupied.contains(neckKey)) continue;

    final path = <Map<String, int>>[
      {'x': headX, 'y': headY},
      {'x': neckX, 'y': neckY},
    ];

    final used = <String>{headKey, neckKey};

    // Grow the tail as a self-avoiding walk from the current tail end.
    var curX = neckX;
    var curY = neckY;

    for (int step = 0; step < targetLen - 2; step++) {
      final next = _pickNextTailCell(
        gridWidth: gridWidth,
        gridHeight: gridHeight,
        curX: curX,
        curY: curY,
        occupied: occupied,
        used: used,
        rng: rng,
      );

      if (next == null) break;
      curX = next.$1;
      curY = next.$2;
      final k = '$curX,$curY';
      used.add(k);
      path.add({'x': curX, 'y': curY});
    }

    if (path.length < 2) continue;

    // Commit occupancy.
    for (final cell in path) {
      occupied.add('${cell['x']},${cell['y']}');
    }

    return {
      'id': 'vine_${vineIndex + 1}',
      'head_direction': headDir,
      'ordered_path': path,
      'vine_color': 'default',
    };
  }

  return null;
}

(int, int)? _pickNextTailCell({
  required int gridWidth,
  required int gridHeight,
  required int curX,
  required int curY,
  required Set<String> occupied,
  required Set<String> used,
  required Random rng,
}) {
  final candidates = <(int, int)>[
    (curX + 1, curY),
    (curX - 1, curY),
    (curX, curY + 1),
    (curX, curY - 1),
  ];

  // Shuffle candidates deterministically.
  for (int i = candidates.length - 1; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final tmp = candidates[i];
    candidates[i] = candidates[j];
    candidates[j] = tmp;
  }

  for (final (nx, ny) in candidates) {
    if (nx < 0 || nx >= gridWidth || ny < 0 || ny >= gridHeight) continue;
    final key = '$nx,$ny';
    if (occupied.contains(key) || used.contains(key)) continue;
    return (nx, ny);
  }

  return null;
}

(int, int) _gridSizeFor(int levelId) {
  // Portrait-friendly grids: keep a consistent 3:4 aspect ratio (width:height).
  // Scale size every ~10 levels to increase difficulty while staying readable.
  final step = (levelId ~/ 10).clamp(0, 5);
  final width = 6 + (step * 3);
  final height = 8 + (step * 4);
  return (width, height);
}

int? _detectNextLevelId(Directory outDir) {
  final re = RegExp(r'level_(\d+)\.json$');
  int? maxId;
  for (final entity in outDir.listSync()) {
    if (entity is! File) continue;
    final match = re.firstMatch(entity.path);
    if (match == null) continue;
    final id = int.tryParse(match.group(1)!);
    if (id == null) continue;
    maxId = (maxId == null) ? id : (id > maxId ? id : maxId);
  }
  return (maxId == null) ? null : (maxId + 1);
}

class _Args {
  final int count;
  final String outDir;
  final int? startId;
  final bool overwrite;

  const _Args({
    required this.count,
    required this.outDir,
    required this.startId,
    required this.overwrite,
  });
}

_Args _parseArgs(List<String> args) {
  int count = 100;
  String outDir = 'assets/levels';
  int? startId;
  bool overwrite = false;

  String? readValue(int index) {
    final a = args[index];
    final eq = a.indexOf('=');
    if (eq != -1) return a.substring(eq + 1);
    if (index + 1 < args.length) return args[index + 1];
    return null;
  }

  for (int i = 0; i < args.length; i++) {
    final a = args[i];

    if (a == '--help' || a == '-h') {
      stdout.writeln(
        'Usage: flutter pub run tool/generate_levels.dart [options]',
      );
      stdout.writeln('');
      stdout.writeln('Options:');
      stdout.writeln(
        '  --count <n>       Number of levels to generate (default: 100)',
      );
      stdout.writeln(
        '  --out <dir>       Output directory (default: assets/levels)',
      );
      stdout.writeln(
        '  --start <id>      Starting level id (default: next after existing)',
      );
      stdout.writeln('  --overwrite       Allow overwriting existing files');
      exitCode = 0;
      exit(0);
    }

    if (a == '--overwrite') {
      overwrite = true;
      continue;
    }

    if (a == '--count' || a.startsWith('--count=')) {
      final value = readValue(i);
      final parsed = int.tryParse(value ?? '');
      if (parsed == null || parsed <= 0) {
        stderr.writeln('Invalid --count: $value');
        exitCode = 2;
        exit(2);
      }
      count = parsed;
      if (!a.contains('=') && i + 1 < args.length) i++;
      continue;
    }

    if (a == '--out' || a.startsWith('--out=')) {
      final value = readValue(i);
      if (value == null || value.trim().isEmpty) {
        stderr.writeln('Invalid --out: $value');
        exitCode = 2;
        exit(2);
      }
      outDir = value;
      if (!a.contains('=') && i + 1 < args.length) i++;
      continue;
    }

    if (a == '--start' || a.startsWith('--start=')) {
      final value = readValue(i);
      final parsed = int.tryParse(value ?? '');
      if (parsed == null || parsed <= 0) {
        stderr.writeln('Invalid --start: $value');
        exitCode = 2;
        exit(2);
      }
      startId = parsed;
      if (!a.contains('=') && i + 1 < args.length) i++;
      continue;
    }

    stderr.writeln('Unknown arg: $a');
    stderr.writeln('Run with --help for usage.');
    exitCode = 2;
    exit(2);
  }

  return _Args(
    count: count,
    outDir: outDir,
    startId: startId,
    overwrite: overwrite,
  );
}
