import 'grid_position.dart';

class Vine {
  final String id;
  final List<GridPosition> path;
  final String color;
  final List<String> blockingVines;
  final String description;

  const Vine({
    required this.id,
    required this.path,
    required this.color,
    required this.blockingVines,
    required this.description,
  });

  Vine copyWith({
    String? id,
    List<GridPosition>? path,
    String? color,
    List<String>? blockingVines,
    String? description,
  }) {
    return Vine(
      id: id ?? this.id,
      path: path ?? this.path,
      color: color ?? this.color,
      blockingVines: blockingVines ?? this.blockingVines,
      description: description ?? this.description,
    );
  }

  bool isBlocked(List<Vine> allVines) {
    for (String blockerId in blockingVines) {
      bool blockerStillExists = allVines.any((v) => v.id == blockerId);
      if (blockerStillExists) return true;
    }
    return false;
  }

  bool isTappable(List<Vine> allVines) => !isBlocked(allVines);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vine && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Vine($id, ${path.length} cells, blocked=$blockingVines)';
}
