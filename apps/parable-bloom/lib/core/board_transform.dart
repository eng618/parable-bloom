import 'game_board_layout.dart';

/// Single source of truth for board placement math.
///
/// The grid, the projection lines, and the cell-to-screen lookup each had
/// their own copy of the center+pan formula, which drifted apart (e.g. the
/// manual lookup ignored the camera). All three delegate here now.
///
/// Pure Dart (doubles/records only) so it stays testable without Flame.
class BoardTransform {
  const BoardTransform._();

  /// Top-left board position in screen space for the centered + panned
  /// layout used by [GridComponent] and [ProjectionLinesComponent].
  static ({double x, double y}) boardPosition({
    required int cols,
    required int rows,
    required double zoom,
    required double panX,
    required double panY,
    required double screenWidth,
    required double screenHeight,
  }) {
    final scaledWidth = GameBoardLayout.boardWidth(cols) * zoom;
    final scaledHeight = GameBoardLayout.boardHeight(rows) * zoom;
    return (
      x: (screenWidth - scaledWidth) / 2 + panX,
      y: (screenHeight - scaledHeight) / 2 + panY,
    );
  }

  /// Screen-space center of grid cell ([x], [y] with y=0 at the bottom),
  /// given the board's top-left ([boardX], [boardY]) and zoom.
  static ({double x, double y}) cellCenter({
    required int x,
    required int y,
    required int gridHeight,
    required double zoom,
    required double boardX,
    required double boardY,
  }) {
    final visualRow = gridHeight - 1 - y;
    return (
      x: boardX + GameBoardLayout.cellCenterX(x) * zoom,
      y: boardY + GameBoardLayout.cellCenterY(visualRow) * zoom,
    );
  }
}
