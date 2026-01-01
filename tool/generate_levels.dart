import 'dart:convert';
import 'dart:io';

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

  final vines = <Map<String, dynamic>>[];
  final occupied = <String>{};

  final horizontalCount = (3 + (levelId ~/ 5)).clamp(3, gridHeight - 1);
  final maxLen = gridWidth.clamp(2, 12);

  for (int i = 0; i < horizontalCount; i++) {
    final length = (2 + (i % (maxLen - 1))).clamp(2, gridWidth);
    final y = i;
    final headX = gridWidth - 1;

    final path = <Map<String, int>>[];
    for (int d = 0; d < length; d++) {
      final x = headX - d;
      final key = '$x,$y';
      if (!occupied.add(key)) {
        throw StateError('Overlap while generating level $levelId at $key');
      }
      path.add({'x': x, 'y': y});
    }

    vines.add({
      'id': 'vine_${i + 1}',
      'head_direction': 'right',
      'ordered_path': path,
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

(int, int) _gridSizeFor(int levelId) {
  final step = (levelId ~/ 10).clamp(0, 5);
  final width = 5 + step;
  final height = 5 + step;
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
