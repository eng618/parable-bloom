import '../../../../core/vine_color_palette.dart';
import '../../../../services/logger_service.dart';

// Module data model
class ModuleData {
  final int id;
  final String name;
  final String themeSeed;
  final List<int> levels;
  final int challengeLevel;
  final Map<String, dynamic> parable;
  final String unlockMessage;

  ModuleData({
    required this.id,
    required this.name,
    required this.themeSeed,
    required this.levels,
    required this.challengeLevel,
    required this.parable,
    required this.unlockMessage,
  });

  // Computed properties for backward compatibility and convenience
  int get startLevel => levels.isNotEmpty
      ? levels.reduce((curr, next) => curr < next ? curr : next)
      : challengeLevel;
  int get endLevel {
    if (levels.isEmpty) return challengeLevel;
    final maxLevel = levels.reduce((curr, next) => curr > next ? curr : next);
    return challengeLevel > 0
        ? (challengeLevel > maxLevel ? challengeLevel : maxLevel)
        : maxLevel;
  }

  int get levelCount => challengeLevel > 0 ? levels.length + 1 : levels.length;
  List<int> get allLevels {
    final result = [...levels];
    if (challengeLevel > 0 && !result.contains(challengeLevel)) {
      result.add(challengeLevel);
    }
    return result..sort();
  }

  bool containsLevel(int levelId) {
    return levels.contains(levelId) ||
        (challengeLevel > 0 && levelId == challengeLevel);
  }

  factory ModuleData.fromJson(Map<String, dynamic> json) {
    return ModuleData(
      id: json['id'] as int,
      name: json['name'] as String,
      themeSeed: (json['theme_seed'] as String?) ?? 'forest',
      levels:
          (json['levels'] as List<dynamic>?)?.map((e) => e as int).toList() ??
              [],
      challengeLevel: (json['challenge_level'] as int?) ?? 0,
      parable: json['parable'] as Map<String, dynamic>,
      unlockMessage: (json['unlock_message'] as String?) ?? '',
    );
  }
}

class MaskData {
  final String mode; // 'hide' or 'show' or 'show-all'
  final List<Map<String, int>> points;

  MaskData({required this.mode, required this.points});

  factory MaskData.fromJson(dynamic json) {
    if (json == null) return MaskData(mode: 'show-all', points: []);

    final mode = (json['mode'] as String?) ?? 'show-all';
    final pts = <Map<String, int>>[];

    if (json['points'] != null) {
      for (final p in json['points']) {
        if (p is List && p.length >= 2) {
          pts.add({'x': p[0] as int, 'y': p[1] as int});
        } else if (p is Map) {
          pts.add({'x': p['x'] as int, 'y': p['y'] as int});
        }
      }
    }

    return MaskData(mode: mode, points: pts);
  }
}

class VineData {
  final String id;
  final String headDirection;
  final List<Map<String, int>>
      orderedPath; // Ordered from head (index 0) to tail (last)
  final String? vineColor;

  VineData({
    required this.id,
    required this.headDirection,
    required this.orderedPath,
    this.vineColor,
  });

  factory VineData.fromJson(Map<String, dynamic> json) {
    final vineColor = json['vine_color']?.toString().trim();
    if (vineColor != null && vineColor.isNotEmpty) {
      if (!VineColorPalette.isKnownKey(vineColor)) {
        LoggerService.warn(
          'Unknown vine_color "$vineColor" will use default color',
          tag: 'VineData',
        );
      }
    }
    return VineData(
      id: json['id'].toString(),
      headDirection: json['head_direction'],
      orderedPath: List<Map<String, int>>.from(
        json['ordered_path'].map(
          (cell) => {'x': cell['x'] as int, 'y': cell['y'] as int},
        ),
      ),
      vineColor: vineColor,
    );
  }
}

class LevelData {
  final int id; // Global level ID (1, 2, 3...)
  final String name;
  final String difficulty;

  /// Canonical grid size for the level.
  ///
  /// Ordering is `[width, height]` where:
  /// - x in `[0, width-1]`
  /// - y in `[0, height-1]`
  final int gridWidth;
  final int gridHeight;
  final List<VineData> vines;
  final int maxMoves;
  final int minMoves;
  final String complexity;
  final int grace;
  final MaskData mask;

  LevelData({
    required this.id,
    required this.name,
    required this.difficulty,
    required this.gridWidth,
    required this.gridHeight,
    required this.vines,
    required this.maxMoves,
    required this.minMoves,
    required this.complexity,
    required this.grace,
    required this.mask,
  });

  factory LevelData.fromJson(Map<String, dynamic> json) {
    final gridSize = json['grid_size'];
    if (gridSize is! List || gridSize.length < 2) {
      throw const FormatException(
        'Level JSON must include grid_size: [width, height]',
      );
    }

    final gridWidth = (gridSize[0] as num).toInt();
    final gridHeight = (gridSize[1] as num).toInt();
    if (gridWidth <= 0 || gridHeight <= 0) {
      throw FormatException(
        'grid_size must be positive; got [$gridWidth, $gridHeight]',
      );
    }

    final vines = List<VineData>.from(
      json['vines'].map((vine) => VineData.fromJson(vine)),
    );

    // Validate vine coordinates are within bounds.
    for (final vine in vines) {
      for (final cell in vine.orderedPath) {
        final x = cell['x'] as int;
        final y = cell['y'] as int;
        if (x < 0 || x >= gridWidth || y < 0 || y >= gridHeight) {
          throw FormatException(
            'Vine ${vine.id} has cell ($x,$y) outside grid_size [$gridWidth,$gridHeight]',
          );
        }
      }
    }

    final mask = MaskData.fromJson(json['mask']);

    // For MVP, mask is visual-only, but we validate that vines never occupy masked-out cells.
    for (final vine in vines) {
      for (final cell in vine.orderedPath) {
        final x = cell['x'] as int;
        final y = cell['y'] as int;
        if (!_isCellVisibleWithMask(mask, x, y)) {
          throw FormatException(
            'Vine ${vine.id} occupies masked-out cell ($x,$y)',
          );
        }
      }
    }

    return LevelData(
      id: json['id'],
      name: json['name'],
      difficulty: json['difficulty'],
      gridWidth: gridWidth,
      gridHeight: gridHeight,
      vines: vines,
      maxMoves: json['max_moves'],
      minMoves: json['min_moves'],
      complexity: json['complexity'],
      grace: json['grace'],
      mask: mask,
    );
  }

  bool isCellVisible(int x, int y) {
    return _isCellVisibleWithMask(mask, x, y);
  }

  // Bounds are now driven by grid_size.
  ({int minX, int maxX, int minY, int maxY}) getBounds() {
    return (minX: 0, maxX: gridWidth - 1, minY: 0, maxY: gridHeight - 1);
  }

  // Get dimensions for backwards compatibility
  int get width => gridWidth;
  int get height => gridHeight;

  static bool _isCellVisibleWithMask(MaskData mask, int x, int y) {
    switch (mask.mode) {
      case 'show-all':
        return true;
      case 'hide':
        return !mask.points.any((p) => p['x'] == x && p['y'] == y);
      case 'show':
        return mask.points.any((p) => p['x'] == x && p['y'] == y);
      default:
        return true;
    }
  }
}
