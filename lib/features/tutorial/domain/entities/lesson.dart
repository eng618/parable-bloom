class Lesson {
  final int id;
  final String title;
  final String objective;
  final String instructions;
  final List<String> learningPoints;
  final List<int> gridSize; // [rows, cols]
  final List<Map<String, dynamic>> vines;

  Lesson({
    required this.id,
    required this.title,
    required this.objective,
    required this.instructions,
    required this.learningPoints,
    required this.gridSize,
    required this.vines,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as int,
      title: json['title'] as String,
      objective: json['objective'] as String,
      instructions: json['instructions'] as String,
      learningPoints: List<String>.from(json['learning_points'] as List),
      gridSize: List<int>.from(json['grid_size'] as List),
      vines: List<Map<String, dynamic>>.from(json['vines'] as List),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'objective': objective,
      'instructions': instructions,
      'learning_points': learningPoints,
      'grid_size': gridSize,
      'vines': vines,
    };
  }

  @override
  String toString() => 'Lesson(id: $id, title: $title)';
}
