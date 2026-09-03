# How to Generate, Validate, and Repair Levels

This guide explains how to use the Go-based `level-builder` CLI tool to generate new puzzle levels, validate their solvability and structure, render ASCII/Unicode previews, and repair invalid level files.

---

## 1. Quick Commands Overview

The project provides Taskfile shortcuts for standard level operations:

```bash
# Validate all existing levels
task levels:validate

# Validate all levels with exact solvability checks (A* / BFS search)
task levels:validate:solvable

# Generate all module levels
task levels:generate:all

# Repair corrupted or broken level files
task levels:repair
```

---

## 2. Generating Levels

### Generating a Single Level

To generate a single level with custom dimensions and difficulty:

```bash
# From repository root
./tools/level-builder/level-builder generate \
  --id 1 \
  --difficulty seedling \
  --width 9 \
  --height 9 \
  --grace 3 \
  --overwrite
```

### Generating Module Batches

To generate a complete module (15 levels per module):

```bash
# Generate Module 1 (Levels 1-15) with Seedling difficulty
./tools/level-builder/level-builder generate module \
  --start 1 \
  --count 1 \
  --base-difficulty seedling

# Generate all 5 standard modules (Levels 1-75)
./tools/level-builder/level-builder generate module \
  --start 1 \
  --count 5 \
  --base-difficulty seedling
```

---

## 3. Validating Levels

Levels must adhere to structural rules (4-connectivity, head orientation, boundary limits, 100% occupancy) and must be mathematically solvable.

### Structural Validation

Runs fast integrity checks across all level JSON files:

```bash
./tools/level-builder/level-builder validate
```

### Solvability Validation

Performs full A* graph search to prove that a legal clearing sequence exists:

```bash
./tools/level-builder/level-builder validate --check-solvable --use-astar --verbose
```

Validation statistics and any failure reports are output to `logs/validation_stats.json`.

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
