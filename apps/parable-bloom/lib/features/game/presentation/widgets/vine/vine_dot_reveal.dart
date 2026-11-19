import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_track.dart';

/// Walks a clearing vine's path and reports each cell the tail uncovers.
///
/// [VinePathCell]s run from the tail, through the old vine, then straight
/// on across the board. A blocked wiggle does not move the cursor, so the
/// later successful clear still throbs every dot once.
final class VineDotReveal {
  int _count = 0;

  /// How many path cells have already been reported.
  int get revealedCount => _count;

  void reset() => _count = 0;

  /// Cells whose dots should throb because the tail has passed them.
  ///
  /// A large step reports every cell the tail has already cleared, not
  /// only the one crossed this frame.
  List<VinePathCell> takeNewlyUncovered(
    List<VinePathCell> cells,
    double tailArc, {
    required bool clearing,
  }) {
    if (!clearing || cells.isEmpty) return const [];
    final start = _count;
    final margin = VineTrack.dotUncoverMargin;
    var i = start;
    while (i < cells.length && tailArc > cells[i].arc + margin) {
      i++;
    }
    if (i == start) return const [];
    _count = i;
    return cells.sublist(start, i);
  }
}
