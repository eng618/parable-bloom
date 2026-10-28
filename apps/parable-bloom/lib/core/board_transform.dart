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

  /// Viewport edge hit by the axis-aligned ray from ([headX], [headY])
  /// along [direction] (`up`/`down`/`left`/`right`), within the viewport
  /// rect ([left], [top], [right], [bottom]) expressed in the same space.
  ///
  /// Used by projection lines so they run exactly to the page edge instead
  /// of stopping at a fixed length or the board bounds. [overshoot] pushes
  /// the point just past the edge so round caps bleed off-screen.
  ///
  /// Returns null when the head is already past the edge in the ray's
  /// direction (nothing ahead to draw) or the direction is unknown.
  static ({double x, double y})? projectToViewportEdge({
    required double headX,
    required double headY,
    required String direction,
    required double left,
    required double top,
    required double right,
    required double bottom,
    double overshoot = 0,
  }) {
    switch (direction) {
      case 'right':
        if (headX >= right) return null;
        return (x: right + overshoot, y: headY);
      case 'left':
        if (headX <= left) return null;
        return (x: left - overshoot, y: headY);
      case 'down':
        if (headY >= bottom) return null;
        return (x: headX, y: bottom + overshoot);
      case 'up':
        if (headY <= top) return null;
        return (x: headX, y: top - overshoot);
      default:
        return null;
    }
  }
}
