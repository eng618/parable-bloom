# Blocking Heuristics

Purpose

- Compute blocking relationships between vines to guide backtracking choices.

Planned API

- BuildBlockingGraph(vines []model.Vine) map[string]map[string]bool
- PickBacktrackCandidates(graph map[string]map[string]bool, failingVine string, window int) []string

Testing

- Unit tests for small synthetic vine layouts that verify computed graph and candidate selection.
- Tests should be deterministic and cover edge cases (multi-block chains, isolated vines).
