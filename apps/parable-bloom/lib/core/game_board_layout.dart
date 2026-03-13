class GameBoardLayout {
  const GameBoardLayout._();

  // Distance between adjacent grid points and vine anchors.
  static const double pointSpacing = 55.0;

  // Visual size of vines and the board's outer bounds.
  static const double cellSize = 72.0;

  // Interactive cell size. Keeping this tied to spacing avoids overlap.
  static const double tapTargetSize = pointSpacing;

  static const double gridDotRadius = 3.0;

  static double get cellInset => (cellSize - tapTargetSize) / 2;

  static double boardWidth(int cols) {
    if (cols <= 0) return 0.0;
    return (cols - 1) * pointSpacing + cellSize;
  }

  static double boardHeight(int rows) {
    if (rows <= 0) return 0.0;
    return (rows - 1) * pointSpacing + cellSize;
  }

  static double cellLeft(int col) => col * pointSpacing + cellInset;

  static double cellTop(int visualRow) => visualRow * pointSpacing + cellInset;

  static double cellCenterX(int col) => col * pointSpacing + cellSize / 2;

  static double cellCenterY(int visualRow) =>
      visualRow * pointSpacing + cellSize / 2;
}
