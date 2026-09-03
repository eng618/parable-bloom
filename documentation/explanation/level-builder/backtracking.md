# Backtracking Module

Purpose

- Implement bounded local backtracking to recover from per-vine placement exhaustion.
- Provide a single function `AttemptLocalBacktrack` with clear inputs and outputs so it can be unit-tested.

API

- AttemptLocalBacktrack(vines []model.Vine, occupied map[string]string, vineID string, targetLen int, p *CenterOutPlacer, w, h int, rng*rand.Rand, config gen2.GenerationConfig) (vine model.Vine, vineOccupied map[string]string, updatedVines []model.Vine, updatedOccupied map[string]string, err error)

Strategy

1. Read `config.BacktrackWindow` (default=3) and `config.MaxBacktrackAttempts` (default=2).
2. For up to `MaxBacktrackAttempts`, remove `BacktrackWindow` vines and try to place the failing vine again.
3. Use conservative fallback order: last N vines first. Later versions may add blocking-graph heuristics.
4. On unrecoverable failure, write a deterministic dump for replay and debugging.

Cycle-breaker repair

- When local backtracking exhausts, the analyzer runs a blocking-graph cycle detection step.
- For each detected cycle the repair attempts targeted removals:
  - Single-vine removals (prefer shorter/low-impact vines);
  - Bounded multi-vine removals (pairs, triplets) where needed to break cycles;
  - Each removal is followed by an attempt to place the failing vine with the updated occupied map.
- This approach is conservative and bounded (limits pair/triplet combinatorics) so it remains deterministic and fast.

Testing

- Unit tests that simulate failing placement and assert successful recovery when allowed.
- Integration tests that replay failing seeds collected in `tools/level-builder/test/fixtures/failing_dumps/`.
- New tests added: `TestCycleBreakerRepairRecovers` and `TestCycleBreakerMultiRemovalRecovers` exercise single- and multi-vine removal repair cases.
