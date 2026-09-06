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

Levels are generated per module (21 levels each; modules 1–5 shipped with
105 levels, modules 6–24 registered for the 504-level cloud set)
following the canonical 21-per-module progression (`tools/level-builder/pkg/common/progression.go`):
5× Seedling, Sprout, Nurturing, Flourishing, then a Transcendent challenge.
Every level must pass acceptance gates (structural + solvable + 100% playable
coverage + quality) before it is written.

```bash
# Canonical flow: generate modules 1-5 (Levels 1-105) with the batch generator
task levels:generate:all

# Generate the cloud expansion, e.g. modules 6-24 (Levels 106-504)
START_MODULE=6 END_MODULE=24 ./generate_all.sh

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

## 6. Uploading Levels to Firestore (dev → preview → prod)

Levels reach players over the air: `levels_{env}/{logicalId}` plus the
`configs_{env}/modules` and `configs_{env}/biblical_themes` registries. The
uploaders validate everything locally first (mappings resolve, JSON parses,
1 MiB doc limits), write via BulkWriter with retry, and support resume.

```bash
# 0. Authenticate once (Admin SDK via ADC)
gcloud auth application-default login

# 1. Dry-run first (no writes, no credentials needed)
task firebase:levels:upload ENV=dev ARGS='--dry-run'
task firebase:themes:upload ENV=dev ARGS='--dry-run'

# 2. Dev: full upload, then verify in Singleton/console + in-app (APP_ENV=dev)
task firebase:levels:upload ENV=dev
task firebase:themes:upload ENV=dev

# 3. Re-run safely any time (skips docs already present)
task firebase:levels:upload ENV=dev ARGS='--only-missing'

# 4. Preview, verify, then prod (local backup first — no billing required)
task firebase:levels:upload ENV=preview
task firebase:themes:upload ENV=preview
task firebase:scriptures:upload ENV=preview
node scripts/firebase/backup_firestore.js prod  # CONFIRM_PROD_BACKUP=yes if asked
CONFIRM_PROD_UPLOAD=yes task firebase:levels:upload ENV=prod
CONFIRM_PROD_UPLOAD=yes task firebase:themes:upload ENV=prod
CONFIRM_PROD_UPLOAD=yes task firebase:scriptures:upload ENV=prod
```

Notes:

* Old-ID docs (e.g. `lvl_seed_01`) remain alongside the new scheme after
  migration uploads; the app only reads mapped IDs, so they are harmless —
  delete them in the console if you want a tidy collection.
* `scripts/levels/check_scripture_texts.py` gates prod: KJV gaps fail,
  missing NET only warns (bundled-KJV fallback covers offline).
* Emulator testing: start a local Firestore emulator, then prefix any
  command with `FIRESTORE_EMULATOR_HOST="localhost:8080"` (prod guard is
  bypassed against the emulator).

## 7. Generator Resilience Workflow

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
