# How to Generate, Validate, and Repair Levels

This guide explains how to use the Go-based `level-builder` CLI tool to generate new puzzle levels, validate their solvability and structure, render ASCII/Unicode previews, and repair invalid level files.

---

## 1. Quick Commands Overview

The project provides Taskfile shortcuts for standard level operations:

```bash
# Validate all existing levels
task levels:validate

# Validate all levels with exact solvability checks (A* / BFS search)
task levels:validate-solvable

# Generate all module levels
task levels:generate:all
```

---

## 2. Generating Levels

### Generating Module Batches (canonical flow)

Levels are generated per module (21 levels each, 105 total across 5 modules)
following the canonical 5×21 progression (`tools/level-builder/pkg/common/progression.go`):
5× Seedling, Sprout, Nurturing, Flourishing, then a Transcendent challenge.
Every level must pass acceptance gates (structural + solvable + 100% playable
coverage + quality) before it is written.

```bash
# Canonical flow: generate all 5 modules (Levels 1-105) with the batch generator
task levels:generate:all

# Or generate a single module (e.g., Module 1 = Levels 1-21)
./tools/level-builder/level-builder batch --module 1 --overwrite --verbose

# Deterministic LIFO run with per-level stats JSON (quality metrics included)
./tools/level-builder/level-builder batch --module 1 --lifo --overwrite --stats-out ./stats
```

---

## 3. Validating Levels

Levels must adhere to structural rules (4-connectivity, head orientation, boundary limits, 100% occupancy) and must be mathematically solvable.

### Structural Validation

Runs fast integrity checks across all level JSON files (ID-filename match,
canonical difficulty lock, occupancy ≥ spec with 5% tolerance, 100% playable
coverage, colors, structural rules):

```bash
./tools/level-builder/level-builder validate
```

### Solvability Validation

Proves a legal clearing sequence exists. A greedy fast-path handles the
common case (complete for current mechanics); exact BFS/A* covers ≤24-vine
levels and a heuristic covers larger ones:

```bash
./tools/level-builder/level-builder validate --check-solvable --use-astar --verbose
```

Validation statistics go to `logs/validation_stats.json`; solver results are
cached in `logs/validation_cache.json` (SHA-256 + SolverVersion).

---

## 4. Visualizing Levels (Rendering)

You can render visual grid previews in terminal using Unicode or ASCII formatting:

```bash
# Render level 1 in Unicode with coordinate labels
./tools/level-builder/level-builder render --id 1 --style unicode --coords

# Render from a specific file
./tools/level-builder/level-builder render --file apps/parable-bloom/assets/levels/level_1.json
```

---

## 5. Repairing Corrupted Levels

If a level JSON file is corrupted or fails validation:

```bash
# Dry run to inspect files that need repair
./tools/level-builder/level-builder repair --dry-run

# Repair files in-place using deterministic seed regeneration
./tools/level-builder/level-builder repair --overwrite
```

---

## 6. Generator Resilience Workflow

When generating dense or complex levels (e.g. Transcendent 16x20 grids), the generator uses a layered resilience strategy:

1. **LIFO Center-Out Generation**: Generates initial vine placement guaranteeing partial solvability.
2. **Local Backtracking**: If high-coverage filler vines create deadlocks, attempts local step rollbacks.
3. **Incremental Solvability Checks**: Validates each added filler incrementally to reject harmful placements early.
4. **Cycle-Breaker Repair**: Analyzes the blocking graph for circular dependencies ($A \rightarrow B \rightarrow C \rightarrow A$) and removes offending pairs/triplets.
5. **Circuit Breaker Fallback**: Bounded state exploration limits prevent infinite loops during batch runs.

For deeper algorithmic details on solver mechanics, see:

- [Backtracking Algorithm](../explanation/level-builder/backtracking.md)
- [Blocking Heuristics](../explanation/level-builder/blocking_heuristics.md)
- [Circuit Breaker Orchestration](../explanation/level-builder/circuit_breaker.md)
- [Filler Phase Mechanics](../explanation/level-builder/filler_phase.md)
- [Incremental Solver](../explanation/level-builder/incremental_solver.md)
- [Level System Reference Specification](../reference/level-system.md)
- [System Architecture](../explanation/architecture.md)
