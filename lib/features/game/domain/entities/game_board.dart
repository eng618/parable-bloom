import 'vine.dart';
import 'grid_position.dart';

class GameBoard {
  final int rows;
  final int cols;
  final List<Vine> vines;

  const GameBoard({
    required this.rows,
    required this.cols,
    required this.vines,
  });

  List<Vine> getTappableVines() {
    return vines.where((vine) => vine.isTappable(vines)).toList();
  }

  Map<GridPosition, String> getCellOccupancy() {
    final occupancy = <GridPosition, String>{};
    for (Vine vine in vines) {
      for (GridPosition pos in vine.path) {
        if (occupancy.containsKey(pos)) {
          throw Exception('OVERLAP: Two vines at $pos');
        }
        occupancy[pos] = vine.id;
      }
    }
    return occupancy;
  }

  GameBoard clearVine(String vineId) {
    final updated = vines.where((v) => v.id != vineId).toList();
    return GameBoard(rows: rows, cols: cols, vines: updated);
  }

  bool isComplete() => vines.isEmpty;

  Vine? getVineById(String id) {
    try {
      return vines.firstWhere((v) => v.id == id);
    } catch (e) {
      return null;
    }
  }

  Vine? getVineAtCell(GridPosition pos) {
    try {
      return vines.firstWhere((vine) => vine.path.contains(pos));
    } catch (e) {
      return null;
    }
  }

  GameBoard copyWith({int? rows, int? cols, List<Vine>? vines}) {
    return GameBoard(
      rows: rows ?? this.rows,
      cols: cols ?? this.cols,
      vines: vines ?? this.vines,
    );
  }

  @override
  String toString() => 'GameBoard(${vines.length} vines, ${rows}x$cols)';
}
