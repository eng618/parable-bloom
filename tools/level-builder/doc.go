// Package main provides the level-builder CLI tool for Parable Bloom.
//
// # Overview
//
// The level-builder is a comprehensive command-line tool for generating, validating,
// rendering, and managing puzzle levels for the Parable Bloom game. It serves as the
// single source of truth for all level-related operations, eliminating duplication
// between the Flutter app and build tooling.
//
// # Key Features
//
//   - Intelligent level generation with solver-aware placement algorithms
//   - Comprehensive structural and solvability validation
//   - Visual ASCII/Unicode rendering for debugging and documentation
//   - Automatic repair of corrupted level files
//   - Module-based batch generation for progressive difficulty
//   - Tutorial/lesson generation and validation
//
// # Installation & Building
//
//	cd tools/level-builder
//	go build
//	./level-builder --help
//
// Or using the project's Taskfile:
//
//	task level-builder:build
//	task level-builder:test
//	task level-builder:lint
//
// # Commands
//
// ## batch
//
// Generate all 21 levels for a module with the canonical 5×21 progression
// (see pkg/common/progression.go — the single source of truth):
//
//	Levels 1-5: Seedling, 6-10: Sprout, 11-15: Nurturing,
//	16-20: Flourishing, 21: Transcendent (challenge).
//
// For module N, level IDs are (N-1)*21+1 through (N-1)*21+21.
// Generation runs through the robust pipeline (pkg/generator/pipeline.go):
// registry strategy → primary placement → gap filler → ID sanitize →
// masking → assembly. Every level is validated (structural + solvable +
// playable coverage + quality gates) before it is accepted.
//
// Examples:
//
//	# Generate module 1 (levels 1-21)
//	level-builder batch --module 1 --overwrite --verbose
//
//	# Deterministic LIFO run with per-level stats
//	level-builder batch --module 2 --lifo --overwrite --stats-out ./stats
//
//	# Preview without writing
//	level-builder batch --module 3 --dry-run
//
// Flags:
//
//	--module           Module ID to generate (1-5, required)
//	--overwrite        Overwrite existing level files
//	--lifo             Prefer center-out strategy (strongest solvability guarantee)
//	--strategy         Force a placement strategy (direction-first, center-out)
//	--aggressive       Stronger backtracking defaults (window=6, attempts=6)
//	--min-coverage     Playable-coverage override 0.0-1.0 (default 1.0)
//	--dump-dir         Failing-generation dumps (default: logs/<timestamp>/failing_dumps)
//	--stats-out        Per-level stats JSON incl. quality metrics (default: logs/<timestamp>/runs/stats)
//	--output-dir       Level output dir (default: resolved via common.LevelsDir())
//	--backup           Backup existing levels before overwriting (default: true)
//	--dry-run          Preview without writing files
//
// ## validate
//
// Validate puzzle levels for structural integrity and solvability.
//
// Performs comprehensive validation including:
//   - Module and level file parsing
//   - ID-filename match and canonical difficulty lock (ExpectedDifficulty)
//   - Grid size and occupancy checks (spec 0.93, tolerance 0.05)
//   - Playable coverage: every non-vine cell must be masked
//   - Color scheme validation
//   - 4-connectivity checks (segments must be adjacent)
//   - Head/neck orientation validation
//   - Circular blocking detection (deadlock prevention)
//   - Mask validation (vines can't occupy hidden cells)
//   - Optional solvability checks using greedy / exact BFS / A* / heuristic
//
// When --check-solvable is enabled, results are written to
// logs/validation_stats.json for detailed analysis including solver
// performance metrics. Results are cached in logs/validation_cache.json
// (SHA-256 + SolverVersion) to keep hot runs fast.
//
// Examples:
//
//	# Quick structural validation only
//	level-builder validate
//
//	# Full validation with solvability checks
//	level-builder validate --check-solvable
//
//	# Validation with custom solver parameters
//	level-builder validate --check-solvable --max-states 100000 --use-astar --astar-weight 10
//
//	# Verbose validation for debugging
//	level-builder validate --check-solvable --verbose
//
// Flags:
//
//	-s, --check-solvable    Run solvability checks (may be slow)
//	--max-states            Max states budget for solver heuristic (default: 100000)
//	--use-astar             Use A* guided search for exact solver (default: true)
//	--astar-weight          Weight multiplier for A* heuristic (default: 10)
//
// Output:
//   - Console: Per-level validation status with timing
//   - logs/validation_stats.json: Detailed metrics (when --check-solvable is used)
//   - logs/validation_cache.json: Solver cache (SHA-256 + SolverVersion)
//
// ## stats
//
// Summarize validation or batch-generation stats JSON files.
//
// Aggregates solver distribution, state budgets, timing, coverage, and
// blocking depth from logs/validation_stats.json (default), tutorial stats,
// or per-level batch stats directories.
//
// Examples:
//
//	# Summarize the latest validation run
//	level-builder stats
//
//	# Tutorial stats
//	level-builder stats --lessons
//
//	# Batch run stats directory
//	level-builder stats --dir logs/<timestamp>/runs/stats
//
//	# Compare experiment files (e.g. BFS vs A*)
//	level-builder stats validation_stats_bfs.json validation_stats_astar.json
//
// Flags:
//
//	--file            Explicit stats file (default: logs/validation_stats.json)
//	--dir             Directory of per-level batch stats to aggregate
//	--lessons         Summarize tutorial stats (validation_stats_lessons.json)
//
// ## render
//
// Render puzzle levels as ASCII or Unicode visualizations.
//
// Generates human-readable grid visualizations for debugging, documentation,
// and visual inspection of level layouts. Supports both ASCII and Unicode
// rendering styles with optional coordinate display.
//
// Examples:
//
//	# Render by level ID (Unicode style)
//	level-builder render --id 1
//
//	# Render from file path
//	level-builder render --file assets/levels/level_42.json
//
//	# ASCII rendering with coordinates
//	level-builder render --id 10 --style ascii --coords
//
//	# Unicode rendering (default style)
//	level-builder render --id 5 --style unicode
//
// Flags:
//
//	--id               Level ID to render
//	--file             Path to level JSON file
//	--style            Rendering style: unicode or ascii (default: unicode)
//	--coords           Show coordinate grid labels
//
// Unicode glyphs: ↑ ↓ ← → (heads), ┼ ├ ┤ ┴ ┬ │ ─ (connectors)
// ASCII glyphs:   ^ v < > (heads), + | - (connectors), o (tail)
//
// ## repair
//
// Scan and repair corrupted or invalid level files.
//
// Detects files that fail to parse and — with --check-solvable (default) —
// files that fail structural validation, the canonical difficulty lock, or
// solvability checks. Regeneration is deterministic (seed = levelID * 31337)
// through canonical pipeline inputs and must pass batch acceptance gates
// (structural + solvable + design constraints) before writing.
//
// Examples:
//
//	# Dry-run to check which files need repair
//	level-builder repair --dry-run
//
//	# Repair files in-place, including unsolvable/structural failures
//	level-builder repair --overwrite
//
//	# Parse failures only (legacy behavior)
//	level-builder repair --check-solvable=false
//
// Flags:
//
//	--directory        Directory containing level files (default: resolved assets levels dir)
//	--overwrite        Overwrite files without prompting (default: true)
//	--dry-run          Show what would be repaired without making changes
//	--fix-duplicates   Cheap duplicate-vine-ID sanitize before full regeneration
//	--check-solvable   Also repair structural/solvability failures (default: true)
//	--max-states       Solver state budget for repair checks (default: 1000000)
//	--aggressive       Stronger backtracking settings when regenerating
//
// Repair process:
//  1. Scan directory for level_*.json files
//  2. Assess each file: parse, ID match, difficulty lock, structural,
//     solvability, design constraints
//  3. Optionally sanitize duplicate vine IDs (--fix-duplicates)
//  4. Regenerate failures via ClearableFirstPlacement + masking
//  5. Validate acceptance gates before writing
//
// ## clean
//
// Remove generated levels and the module registry. Destructive — requires
// explicit invocation and is never run as part of generation or validation.
//
// Examples:
//
//	level-builder clean
//
// Removes:
//   - <assets>/levels/level_*.json
//   - <assets>/data/modules.json
//
// ## tutorials
//
// Validate tutorial/lesson files with special rules.
//
// Tutorial validation has stricter requirements than regular levels:
//   - Simpler layouts for teaching
//   - Required instructional metadata
//   - Guaranteed solvability
//   - Progressive difficulty within lesson sequence
//
// Examples:
//
//	# Validate all lesson files
//	level-builder validate-tutorials
//
// Lesson files location: apps/parable-bloom/assets/lessons/lesson_*.json
//
// # Architecture
//
// The level-builder follows a clean architecture with separation of concerns:
//
// ## Package Structure
//
//	cmd/              - Cobra command implementations
//	  ├─ batch/       - Module batch generation (canonical entry point)
//	  ├─ validate/    - Validation commands
//	  ├─ render/      - Rendering commands
//	  ├─ repair/      - Repair commands
//	  ├─ clean/       - Cleanup commands
//	  └─ tutorials/   - Tutorial validation
//	pkg/
//	  ├─ common/      - Shared types, utilities, logging, progression, paths
//	  ├─ generator/   - Level generation algorithms
//	  │  ├─ pipeline.go          - Canonical GenerateRobust pipeline
//	  │  ├─ api.go               - GenerateLevel wrappers + atomic writes
//	  │  ├─ assembler.go         - Final Level assembly (round-robin colors)
//	  │  ├─ registry.go          - Strategy registry
//	  │  ├─ strategies/          - Placement strategies, gap filler, backtracking, analyzer
//	  │  ├─ utils/              - Presets, direction utils, blocking heuristics
//	  │  ├─ metrics/            - Coverage, complexity, quality reports
//	  │  └─ config/             - DifficultySpecs, GridSizeRanges, GenerationConfig
//	  ├─ batch/       - Concurrent module generation + quality gates
//	  ├─ validator/   - Validation logic
//	  │  ├─ validator.go          - Main validation orchestration + cache
//	  │  ├─ structural.go         - Structural checks
//	  │  ├─ solvability.go        - Greedy/exact/A*/heuristic solvers
//	  │  ├─ astar.go              - A* search
//	  │  ├─ generation_checks.go  - Design constraints for the generator loop
//	  │  ├─ cache.go              - Validation cache (logs/)
//	  │  └─ tutorials_validator.go - Relaxed lesson validation
//	  └─ model/       - Data models (Level, Vine, Module, Mask, Parable)
//
// ## Key Algorithms
//
// ### Robust Pipeline (GenerateRobust)
//
//  1. Registry strategy placement (center-out LIFO guarantee, direction-first
//     organic shapes, or legacy clearable-first for dense coverage)
//  2. Local backtracking recovery inside the placer
//  3. Aggressive gap filling for full playable coverage
//  4. Vine ID sanitization (sequential vine_1..N)
//  5. Masking of leftover empties (hide mode)
//  6. Assembly with round-robin color assignment and spec grace
//
// ### Validation Pipeline
//
//  1. Parse JSON and check schema compliance
//  2. Verify ID matches filename and difficulty matches canonical progression
//  3. Validate grid dimensions and color schemes
//  4. Check vine occupancy against spec (0.93, tolerance 0.05)
//  5. Check 100% playable coverage (occupied OR masked)
//  6. Structural validation (connectivity, orientation, bounds)
//  7. Circular blocking detection (DFS cycle detection)
//  8. Optional solvability check (greedy fast-path, exact/A* ≤24 vines,
//     heuristic beyond; greedy is complete for current mechanics)
//
// # Development Workflow
//
// ## Typical Level Generation Flow
//
//	# 1. Generate a module (canonical progression, validates each level)
//	level-builder batch --module 1 --overwrite --verbose
//
//	# 2. Validate structural integrity (+ difficulty lock, occupancy, coverage)
//	level-builder validate
//
//	# 3. Check solvability (greedy fast-path, exact/A* where needed)
//	level-builder validate --check-solvable
//
//	# 4. Visual inspection
//	level-builder render --id 50
//
//	# 5. If issues found, repair
//	level-builder repair --dry-run
//	level-builder repair
//
// ## Testing New Features
//
//	# Run Go tests
//	go test ./...
//
//	# Run with verbose logging
//	level-builder validate --check-solvable --verbose
//
//	# Validate with detailed metrics
//	level-builder validate --check-solvable --verbose
//
//	# Check linting
//	golangci-lint run
//
// ## Regenerating All Levels
//
//	# Backup existing levels (also automatic with batch --overwrite --backup)
//	cp -r apps/parable-bloom/assets/levels apps/parable-bloom/assets/levels_backup
//
//	# Generate all modules via the repo task (batch --module 1..5 + validate)
//	task levels:generate:all
//
//	# Validate everything
//	level-builder validate --check-solvable
//
// # Configuration
//
// ## Global Flags (available for all commands)
//
//	-v, --verbose              Enable verbose output for debugging
//	-j, --workers string       Number of concurrent workers (integer, 'half', or 'full')
//	-w, --working-dir string   Working directory for asset paths
//
// ## Path Resolution
//
// The level-builder uses a smart path resolution strategy to support the monorepo
// structure. It searches up the directory tree for marker files (nx.json, bun.lock,
// or pubspec.yaml) to identify the repository root. Once identified, it looks for
// assets in:
//  1. apps/parable-bloom/assets (Monorepo standard)
//  2. assets (Standalone/Legacy standard)
//
// This allows the tool to be run from any subdirectory within the monorepo.
//
// ## Environment Variables
//
// The tool respects standard Go environment variables and can be configured
// via command-line flags. No external configuration files required.
//
// # Integration with Parable Bloom
//
// The level-builder is the authoritative source for level data in Parable Bloom.
// The Flutter app reads the generated JSON files at runtime but does NOT
// perform generation or comprehensive validation. This ensures:
//
//   - Consistent level quality across all platforms
//   - Faster app startup (no runtime generation)
//   - Reproducible levels across builds
//   - Single source of truth for validation rules
//
// Level files location: parable-bloom/assets/levels/level_*.json
// Lesson files location: parable-bloom/assets/lessons/lesson_*.json
// Module config: parable-bloom/assets/data/modules.json
//
// # Migration Notes
//
// This tool replaces the previous level generation logic in the eng CLI and
// the validation logic in Dart tests (test/level_validation_test.dart). The
// Dart tests now serve as lightweight smoke tests only, with the note:
//
//	"Comprehensive level validation is now performed by the Go level-builder CLI"
//
// # References
//
// For more information:
//   - Project README: parable-bloom/README.md
//   - Architecture docs: parable-bloom/documentation/explanation/architecture.md
//   - Run --help on any command for detailed usage
//
// # Version History
//
// The level-builder was developed in phases:
//   - Step 1: Cobra CLI framework and command structure
//   - Step 2: Common infrastructure (logging, models, solver)
//   - Step 3: Tiling algorithm and solver-aware placement
//   - Step 4: Render and repair commands
//   - Step 5: Comprehensive structural validation (single source of truth)
//   - Step 6: Final regeneration and production deployment (pending)
package main
