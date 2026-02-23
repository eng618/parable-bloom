/// Vine data structure for lessons
class LessonVineData {
  final String id;
  final String headDirection;
  final List<Map<String, int>> orderedPath;

  const LessonVineData({
    required this.id,
    required this.headDirection,
    required this.orderedPath,
  });

  factory LessonVineData.fromJson(Map<String, dynamic> json) {
    return LessonVineData(
      id: json['id'] as String,
      headDirection: json['head_direction'] as String,
      orderedPath: List<Map<String, int>>.from(
        (json['ordered_path'] as List).map(
          (cell) => {
            'x': (cell['x'] as num).toInt(),
            'y': (cell['y'] as num).toInt(),
          },
        ),
      ),
    );
  }

  @override
  String toString() => 'LessonVineData(id: $id)';
}

/// Lesson data for rendering in the game screen
class LessonData {
  final int id; // Lesson ID (1-5)
  final String title;
  final String objective;
  final String instructions;
  final List<String> learningPoints;
  final int gridWidth;
  final int gridHeight;
  final List<LessonVineData> vines;

  const LessonData({
    required this.id,
    required this.title,
    required this.objective,
    required this.instructions,
    required this.learningPoints,
    required this.gridWidth,
    required this.gridHeight,
    required this.vines,
  });

  factory LessonData.fromJson(Map<String, dynamic> json) {
    const int kMaxTitleLength = 80;
    const int kMaxObjectiveLength = 120;
    const int kMaxInstructionsLength = 200;
    const int kMaxLearningPointLength = 80;
    const int kMinLearningPoints = 2;

    final gridSize = json['grid_size'] as List;
    if (gridSize.length < 2) {
      throw const FormatException('grid_size must have [rows, cols]');
    }

    final gridRows = (gridSize[0] as num).toInt();
    final gridCols = (gridSize[1] as num).toInt();

    final vines = (json['vines'] as List)
        .map((vine) => LessonVineData.fromJson(vine as Map<String, dynamic>))
        .toList();

    // Validate vine coordinates are within bounds
    for (final vine in vines) {
      for (final cell in vine.orderedPath) {
        final x = cell['x']!;
        final y = cell['y']!;
        if (x < 0 || x >= gridCols || y < 0 || y >= gridRows) {
          throw FormatException(
            'Vine ${vine.id} has cell ($x,$y) outside grid_size [$gridRows,$gridCols]',
          );
        }
      }
    }

    // Text fields: trim and validate lengths
    final title = (json['title'] as String).trim();
    final objective = (json['objective'] as String).trim();
    final instructions = (json['instructions'] as String).trim();
    final learningPoints = List<String>.from(json['learning_points'] as List)
        .map((e) => e.toString().trim())
        .toList();

    if (title.isEmpty || title.length > kMaxTitleLength) {
      throw FormatException('title must be 1..$kMaxTitleLength chars');
    }
    if (objective.isEmpty || objective.length > kMaxObjectiveLength) {
      throw FormatException('objective must be 1..$kMaxObjectiveLength chars');
    }
    if (instructions.isEmpty || instructions.length > kMaxInstructionsLength) {
      throw FormatException(
          'instructions must be 1..$kMaxInstructionsLength chars');
    }
    if (learningPoints.length < kMinLearningPoints) {
      throw FormatException(
          'learning_points must contain at least $kMinLearningPoints items');
    }
    for (final p in learningPoints) {
      if (p.isEmpty || p.length > kMaxLearningPointLength) {
        throw FormatException(
            'each learning_point must be 1..$kMaxLearningPointLength chars');
      }
    }

    return LessonData(
      id: json['id'] as int,
      title: title,
      objective: objective,
      instructions: instructions,
      learningPoints: learningPoints,
      gridWidth: gridCols,
      gridHeight: gridRows,
      vines: vines,
    );
  }

  @override
  String toString() => 'LessonData(id: $id, title: $title)';
}
