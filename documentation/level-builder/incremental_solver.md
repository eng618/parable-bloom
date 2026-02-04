# Incremental Solver

Purpose

- Provide a cheap, early solvability check that is less expensive than full A*.

Design

- Implement `IsLikelySolvablePartial(level, maxDepth int) bool` which performs blocking-only checks, shallow BFS, or depth-limited A*.
- Use this during filler phases and after local backtracking to accept promising states before invoking full solver.

Testing

- Unit tests that compare behavior with full solver on small levels to validate the heuristic's recall/precision.
