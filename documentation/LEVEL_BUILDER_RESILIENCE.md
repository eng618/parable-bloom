# Level Builder Resilience

This document outlines the resilience strategy for the level-builder generator. It describes modular subsystems (backtracking, filler check, blocking heuristics, incremental solver, circuit breaker orchestration), testing strategy, and CI practices to move the generator toward near-100% usable-level generation.

See the `documentation/level-builder/` directory for per-module specifications and test plans.

Goals

- Reproducible failure capture (dumps + replayability)
- Modular, testable fixes that are easy to tune
- Conservative defaults with an `--aggressive` flag for batch runs
- CI regression tests for real-world failing seeds

High-level workflow

1. Try LIFO (center-out) for fast guaranteed-partial solvability
2. If high-coverage + non-LIFO fillers cause unsolvability: attempt local backtracking
3. If local backtracking fails, run incremental solvability checks and selective re-fill
4. If still failing, escalate to longer backtrack windows or solver-driven fallback behind circuit-breaker thresholds

Recovery heuristics should be parameterized and exposed via CLI flags for tuning.

Contact: Level Builder Owners (see documentation/ARCHITECTURE.md for owners and context)
