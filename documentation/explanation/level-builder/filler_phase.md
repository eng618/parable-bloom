# Filler Phase

Purpose

- Raise coverage after the primary placer without covering the board in 2-cell vines.

Behavior

1. `ExtendIntoGaps` appends empty neighbors onto existing tails. Short vines are extended first. Each append is kept only when the greedy solver still passes. Growth stops once average length reaches the tier maximum.
2. `GapFiller` then places vines of length 3–5 into what remains. The pipeline keeps that prefix only while average length stays inside the tier band and short vines stay at or below 15%.
3. 2-cell vines are a last resort, and only while more than 3% of the board is empty. The rest is masked so playable coverage stays 100%.
4. A second extend pass lengthens the new fillers into any cell they can reach. An extension that would lay the vine across its own exit ray is discarded. The greedy solver slides a vine forward and would keep that shape; the structural check will not.
5. Adjacent holes that are still over the 3% mask budget become 2-cell vines when the length band, the short-vine cap, and the greedy solver still hold.
6. Pockets that do not touch a tail are walked into by the vine that borders them. The vine retracts to that border cell, covers the pocket, and other tails may reclaim the freed cells. The walk is kept only when the mask shrinks and the length band, short-vine cap, free-vine share, and greedy solver still hold.

Batch validation runs before the level file is written. A rejected attempt does not block the next seed.

`IsLikelySolvablePartial` is a unit-tested approximation that only inspects the cell in front of a head. The pipeline does not use it. Acceptance uses `common.Solver.IsSolvableGreedy`, which walks the full exit ray. That greedy check is complete for the current rules.

The batch gate (`metrics.CheckContract`) then rejects a candidate whose short-vine share is above 15% or whose mask is above 3% of the grid.
