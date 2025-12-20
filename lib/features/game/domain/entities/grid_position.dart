class GridPosition {
  final int row;
  final int col;

  const GridPosition(this.row, this.col);

  bool isAdjacentOrthogonal(GridPosition other) {
    if (row == other.row && (col - other.col).abs() == 1) return true;
    if (col == other.col && (row - other.row).abs() == 1) return true;
    return false;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GridPosition &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          col == other.col;

  @override
  int get hashCode => row.hashCode ^ col.hashCode;

  @override
  String toString() => '[$row,$col]';
}
