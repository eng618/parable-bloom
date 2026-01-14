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
// ## generate
//
// Generate new puzzle levels with intelligent vine placement algorithms.
//
// The generator uses a tiling algorithm that places vine segments into rectangular
// regions, then uses solver-aware placement to introduce blocking complexity for
// higher difficulties. Supports batch generation with module organization.
//
// Examples:
//
//	# Generate a single level
//	level-builder generate --id 1 --difficulty sapling --grace 3
//
//	# Generate with specific grid size
//	level-builder generate --id 42 --width 8 --height 10 --difficulty oak
//
//	# Generate module batches (10 levels + 1 challenge)
//	level-builder generate module --start 1 --count 5 --base-difficulty seedling
//
//	# Generate with custom seed for reproducibility
//	level-builder generate --id 10 --seed 12345
//
// Flags:
//
//	--id              Level ID (required)
//	--difficulty      Difficulty tier (seedling, sapling, oak, redwood)
//	--width           Grid width (default: varies by difficulty)
//	--height          Grid height (default: varies by difficulty)
//	--grace           Lives/mistakes allowed (default: 3)
//	--seed            Random seed for deterministic generation
//	--overwrite       Overwrite existing level file
//
// Module generation flags:
//
//	--start           Starting module number
//	--count           Number of modules to generate
//	--base-difficulty Base difficulty for progression
//
// ## validate
//
// Validate puzzle levels for structural integrity and solvability.
//
// Performs comprehensive validation including:
//   - Module and level file parsing
//   - Grid size and occupancy checks
//   - Color scheme validation
//   - 4-connectivity checks (segments must be adjacent)
//   - Head/neck orientation validation
//   - Circular blocking detection (deadlock prevention)
//   - Mask validation (vines can't occupy hidden cells)
//   - Optional solvability checks using BFS or A* algorithms
//
// When --check-solvable is enabled, results are written to validation_stats.json
// for detailed analysis including solver performance metrics.
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
//   - validation_stats.json: Detailed metrics (when --check-solvable is used)
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
// Scan and repair corrupted level files.
//
// Automatically detects and regenerates level files that fail to parse or
// validate. Uses deterministic seed-based regeneration (level_id * 31337)
// to ensure reproducible repairs. Validates solvability before writing.
//
// Examples:
//
//	# Dry-run to check which files need repair
//	level-builder repair --dry-run
//
//	# Repair all corrupted files in default directory
//	level-builder repair
//
//	# Repair specific directory
//	level-builder repair --directory path/to/levels
//
//	# Force overwrite without prompting
//	level-builder repair --overwrite
//
// Flags:
//
//	--directory        Directory containing level files (default: ../../assets/levels)
//	--overwrite        Overwrite files without prompting
//	--dry-run          Show what would be repaired without making changes
//
// Repair process:
//  1. Scan directory for level_*.json files
//  2. Attempt to read and parse each file
//  3. If parsing fails, regenerate using TileGridIntoVines
//  4. Validate solvability before writing
//  5. Write repaired file with backup of original
//
// ## clean
//
// Remove generated metadata and temporary files.
//
// Cleans up generation metadata files to prepare for fresh generation runs.
// Useful for testing and ensuring clean state.
//
// Examples:
//
//	level-builder clean
//
// Removes:
//   - generation_metadata.json (module generation tracking)
//   - validation_stats.json (validation metrics)
//   - Temporary files from failed generations
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
//	level-builder tutorials validate
//
//	# Validate specific lesson
//	level-builder tutorials validate --id 1
//
// Lesson files location: ../../assets/lessons/lesson_*.json
//
// # Architecture
//
// The level-builder follows a clean architecture with separation of concerns:
//
// ## Package Structure
//
//	cmd/              - Cobra command implementations
//	  ├─ generate/    - Level generation commands
//	  ├─ validate/    - Validation commands
//	  ├─ render/      - Rendering commands
//	  ├─ repair/      - Repair commands
//	  ├─ clean/       - Cleanup commands
//	  └─ tutorials/   - Tutorial validation
//	pkg/
//	  ├─ common/      - Shared types, utilities, logging
//	  ├─ generator/   - Level generation algorithms
//	  │  ├─ tiling.go           - Core tiling algorithm
//	  │  ├─ solver_aware.go     - Intelligent placement
//	  │  └─ module_generation.go - Batch generation
//	  ├─ validator/   - Validation logic
//	  │  ├─ validator.go        - Main validation orchestration
//	  │  ├─ structural.go       - Structural checks
//	  │  └─ solver.go           - Solvability algorithms
//	  └─ model/       - Data models (Level, Vine, Module)
//
// ## Key Algorithms
//
// ### Tiling Algorithm (TileGridIntoVines)
//
// Divides the grid into rectangular regions and fills each with a single vine:
//  1. Calculate region dimensions using square root heuristics
//  2. Randomly assign each region to a vine
//  3. Snake-fill each region with connected segments
//  4. Assign random head directions
//  5. Validate and repair disconnections
//
// ### Solver-Aware Placement
//
// For higher difficulties, introduces controlled blocking:
//  1. Generate base level with tiling
//  2. Analyze vine relationships and solver behavior
//  3. Strategically reposition vines to create blocking chains
//  4. Predict exit paths to create controlled complexity
//  5. Validate solvability with configurable search budgets
//
// ### Validation Pipeline
//
//  1. Parse JSON and check schema compliance
//  2. Verify ID matches filename
//  3. Validate grid dimensions and color schemes
//  4. Check 100% occupancy (or proper mask usage)
//  5. Structural validation (connectivity, orientation, bounds)
//  6. Circular blocking detection (DFS cycle detection)
//  7. Optional solvability check (BFS or A* search)
//
// # Development Workflow
//
// ## Typical Level Generation Flow
//
//	# 1. Generate new levels for a module
//	level-builder generate module --start 5 --count 1 --base-difficulty oak
//
//	# 2. Validate structural integrity
//	level-builder validate
//
//	# 3. Check solvability
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
//	level-builder generate --id 99 --verbose
//
//	# Validate with detailed metrics
//	level-builder validate --check-solvable --verbose
//
//	# Check linting
//	golangci-lint run
//
// ## Regenerating All Levels
//
//	# Backup existing levels
//	cp -r assets/levels assets/levels_backup
//
//	# Clean state
//	level-builder clean
//
//	# Generate all modules (adjust count as needed)
//	level-builder generate module --start 1 --count 5 --base-difficulty seedling
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
//   - Architecture docs: parable-bloom/documentation/ARCHITECTURE.md
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
