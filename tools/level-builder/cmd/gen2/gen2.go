/*
Package gen2 provides the command-line interface for generating levels using advanced algorithms.

The gen2 command generates levels with complex, winding vine patterns optimized for various difficulty tiers.
It supports all difficulty levels from Seedling to Transcendent, with appropriate grid sizes, vine counts,
and blocking complexity. The command offers two generation modes: default direction-first placement with
A* solvability checks, and LIFO mode using center-out placement for guaranteed solvability and 100% coverage.

Key features:
- Difficulty-based parameter calculation (grid size, vine count, max moves, target coverage)
- Reproducible generation via seed control or randomization
- Performance monitoring and detailed statistics reporting
- Visual level rendering for inspection
- Output to JSON files for integration with the game

Usage examples:

	level-builder gen2 --level-id 1000 --difficulty Transcendent
	level-builder gen2 --level-id 1001 --difficulty Flourishing --randomize
	level-builder gen2 --level-id 1002 --difficulty Seedling --strategy center-out
	level-builder gen2 --level-id 1003 --difficulty Nurturing --seed 12345

The command validates input parameters, configures generation based on difficulty specs,
executes the generation algorithm, reports results, and optionally visualizes the level.
*/
package gen2

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/spf13/cobra"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/gen2"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

var (
	levelID    int
	outputFile string
	randomize  bool
	seed       int64
	overwrite  bool
	difficulty string
	strategy   string
	useLIFO    bool // Deprecated: use --strategy center-out

	// Backtracking flags (optional)
	backtrackWindow      int
	maxBacktrackAttempts int
	dumpDir              string // Aggressive mode for batch runs (larger window and attempts)
	aggressive           bool
	statsOut             string // Optional JSON/CSV output path for generation stats
)

// gen2Cmd represents the gen2 command
var gen2Cmd = &cobra.Command{
	Use:   "gen2",
	Short: "Generate levels with advanced algorithms for any difficulty tier",
	Long: `Generate levels using advanced algorithms optimized for complex, winding vine patterns.
Supports all difficulty tiers with appropriate grid sizes, vine counts, and blocking complexity.

Available difficulties:
  - Seedling: 6×8 to 8×10 grids, 6-8 vines, linear/simple blocking
  - Sprout: 8×10 to 10×12 grids, 10-14 vines, simple chains
  - Nurturing: 10×14 to 12×16 grids, 18-28 vines, multi-chains
  - Flourishing: 12×16 to 16×20 grids, 36-50 vines, deep blocking
  - Transcendent: 16×24+ grids, 60+ vines, cascading locks (circuit-board aesthetics)

Generation Modes:
  - Default: Direction-first placement with A* solvability checks
  - Center-Out (--strategy center-out): Center-out placement with LIFO guarantee (100% coverage)

Examples:
  level-builder gen2 --level-id 1000 --difficulty Transcendent
  level-builder gen2 --level-id 1001 --difficulty Flourishing --randomize
  level-builder gen2 --level-id 1002 --difficulty Seedling --strategy center-out
  level-builder gen2 --level-id 1003 --difficulty Nurturing --seed 12345`,
	RunE: func(cmd *cobra.Command, args []string) error {
		common.Info("Starting gen2 level generation...")

		// Validate parameters
		if levelID <= 0 {
			return fmt.Errorf("level-id must be positive")
		}

		// Get difficulty specs
		spec, ok := generator.DifficultySpecs[difficulty]
		if !ok {
			return fmt.Errorf("unknown difficulty: %s (available: Seedling, Sprout, Nurturing, Flourishing, Transcendent)", difficulty)
		}

		gridRange := generator.GridSizeRanges[difficulty]

		// Set level parameters based on difficulty - use proper grid size ranges
		gridWidth := (gridRange.MinW + gridRange.MaxW) / 2
		gridHeight := (gridRange.MinH + gridRange.MaxH) / 2

		// Calculate appropriate vine count based on grid size and average length
		totalCells := gridWidth * gridHeight
		avgLength := (spec.AvgLengthRange[0] + spec.AvgLengthRange[1]) / 2
		if avgLength < 2 {
			avgLength = 2
		}

		// Target coverage from difficulty spec, or 100% for LIFO mode
		var targetCoverage float64
		if strategy == gen2.StrategyCenterOut || useLIFO {
			targetCoverage = 1.0 // LIFO mode targets 100% coverage
			common.Verbose("LIFO mode: targeting 100%% coverage with center-out placement")
		} else {
			targetCoverage = getCoverageForDifficulty(difficulty)
		}
		targetOccupiedCells := int(float64(totalCells) * targetCoverage)
		vineCount := targetOccupiedCells / avgLength

		// Clamp vine count to spec range
		if vineCount < spec.VineCountRange[0] {
			vineCount = spec.VineCountRange[0]
		}
		if vineCount > spec.VineCountRange[1] {
			vineCount = spec.VineCountRange[1]
		}

		// Additional sanity check: don't exceed 1/4 of grid cells as vine heads
		if vineCount > totalCells/4 {
			vineCount = totalCells / 4
		}
		if vineCount < 3 {
			vineCount = 3
		}

		// Calculate max moves based on vine count
		maxMoves := vineCount * 2

		common.Verbose("Generating %s level %d", difficulty, levelID)
		common.Verbose("Grid size: %dx%d (%d cells)", gridWidth, gridHeight, totalCells)
		common.Verbose("Vine count: %d (avg length: %d)", vineCount, avgLength)
		common.Verbose("Target coverage: %.0f%%", targetCoverage*100)
		common.Verbose("Max moves: %d", maxMoves)

		if randomize {
			common.Verbose("Using randomized seed")
		} else if seed != 0 {
			common.Verbose("Using seed: %d", seed)
		}

		// Create generation config
		// Apply conservative defaults unless aggressive mode requested
		if backtrackWindow == 0 {
			if aggressive {
				backtrackWindow = 6
			} else {
				backtrackWindow = 3
			}
		}
		if maxBacktrackAttempts == 0 {
			if aggressive {
				maxBacktrackAttempts = 6
			} else {
				maxBacktrackAttempts = 2
			}
		}

		config := gen2.GenerationConfig{
			LevelID:              levelID,
			GridWidth:            gridWidth,
			GridHeight:           gridHeight,
			VineCount:            vineCount,
			MaxMoves:             maxMoves,
			OutputFile:           outputFile,
			Randomize:            randomize,
			Seed:                 seed,
			Overwrite:            overwrite,
			MinCoverage:          targetCoverage,
			Difficulty:           difficulty,
			Strategy:             strategy,
			BacktrackWindow:      backtrackWindow,
			MaxBacktrackAttempts: maxBacktrackAttempts,
			DumpDir:              dumpDir,
		}

		if strategy == "" && useLIFO {
			config.Strategy = gen2.StrategyCenterOut
		}

		// Start performance monitoring
		startTime := time.Now()

		// Generate the level using appropriate method
		var level model.Level
		var stats gen2.GenerationStats
		var err error

		if config.Strategy == gen2.StrategyCenterOut {
			common.Info("Using LIFO generation (center-out placement with guaranteed solvability)")
			level, stats, err = gen2.GenerateLevelLIFO(config)
		} else {
			level, stats, err = gen2.GenerateLevel(config)
		}
		if err != nil {
			return fmt.Errorf("generation failed: %w", err)
		}

		generationTime := time.Since(startTime)

		// Report results
		common.Info("✓ Successfully generated %s level %d", difficulty, levelID)
		if useLIFO {
			common.Info("  Mode: LIFO (center-out, guaranteed solvable)")
		}
		common.Info("  Generation time: %v", generationTime)
		common.Info("  Placement attempts: %d", stats.PlacementAttempts)
		if !useLIFO {
			common.Info("  Solvability checks: solver=%s states=%d gave_up=%v", stats.SolvabilityChecks.Solver, stats.SolvabilityChecks.StatesExplored, stats.SolvabilityChecks.GaveUp)
		}
		common.Info("  Max blocking depth: %d", stats.MaxBlockingDepth)
		common.Info("  Grid coverage: %.1f%%", stats.GridCoverage*100)

		if outputFile != "" {
			common.Info("  Output file: %s", outputFile)
		} else {
			common.Info("  Output file: assets/levels/level_%d.json", levelID)
		}

		// Render the generated level for visual inspection
		common.Info("")
		common.Info("Generated level visualization:")
		common.Info("")

		// Convert model.Level to model.Level for rendering
		commonLevel := convertModelLevelToCommon(level)

		// Render the level directly
		common.RenderLevelToWriter(cmd.OutOrStdout(), &commonLevel, "unicode", false)

		// Optionally dump stats to file
		if statsOut != "" {
			outDir := filepath.Dir(statsOut)
			if outDir != "" {
				_ = os.MkdirAll(outDir, 0755)
			}
			statsObj := map[string]interface{}{
				"level_id":             levelID,
				"generation_time_sec":  generationTime.Seconds(),
				"placement_attempts":   stats.PlacementAttempts,
				"backtracks_attempted": stats.BacktracksAttempted,
				"dumps_produced":       stats.DumpsProduced,
				"max_blocking_depth":   stats.MaxBlockingDepth,
				"grid_coverage":        stats.GridCoverage,
				"solvability_solver":   stats.SolvabilityChecks.Solver,
				"solvability_states":   stats.SolvabilityChecks.StatesExplored,
			}
			if stats.BlockingDepthSamples > 0 {
				statsObj["avg_blocking_depth"] = float64(stats.TotalBlockingDepth) / float64(stats.BlockingDepthSamples)
			}
			b, _ := json.MarshalIndent(statsObj, "", "  ")
			_ = os.WriteFile(statsOut, b, 0644)
			common.Info("Wrote generation stats: %s", statsOut)
		}

		return nil
	},
}

func init() {
	gen2Cmd.Flags().IntVar(&levelID, "level-id", 0, "unique level ID (required, must be positive)")
	gen2Cmd.Flags().StringVar(&difficulty, "difficulty", "", "difficulty tier (required: Seedling, Sprout, Nurturing, Flourishing, Transcendent)")
	gen2Cmd.Flags().StringVar(&outputFile, "output-file", "", "output file path (default: assets/levels/level_{id}.json)")
	gen2Cmd.Flags().BoolVar(&randomize, "randomize", false, "use time-based random seed")
	gen2Cmd.Flags().Int64Var(&seed, "seed", 0, "specific seed for reproducible generation")
	gen2Cmd.Flags().BoolVar(&overwrite, "overwrite", false, "overwrite existing files")
	gen2Cmd.Flags().StringVar(&strategy, "strategy", "", "placement strategy (direction-first, center-out)")
	gen2Cmd.Flags().BoolVar(&useLIFO, "lifo", false, "DEPRECATED: use --strategy center-out")

	// Backtracking CLI flags
	gen2Cmd.Flags().IntVar(&backtrackWindow, "backtrack-window", 0, "local backtrack window (how many prior vines to remove on failure). Default: 3")
	gen2Cmd.Flags().IntVar(&maxBacktrackAttempts, "max-backtrack-attempts", 0, "max local backtrack retries to try before giving up. Default: 2")
	gen2Cmd.Flags().StringVar(&dumpDir, "dump-dir", "", "directory to write failing generation dumps (default: tools/level-builder/failing_dumps)")
	gen2Cmd.Flags().BoolVar(&aggressive, "aggressive", false, "enable aggressive backtracking defaults for batch runs (window=6 attempts=6)")
	gen2Cmd.Flags().StringVar(&statsOut, "stats-out", "", "optional path to write generation stats as JSON")

	// Mark required flags
	_ = gen2Cmd.MarkFlagRequired("level-id")
	_ = gen2Cmd.MarkFlagRequired("difficulty")
}

// GetCommand returns the gen2 command for registration with root
func GetCommand() *cobra.Command {
	return gen2Cmd
}

// getCoverageForDifficulty returns the target coverage for each difficulty tier.
// Higher difficulties have lower coverage requirements to allow for complex blocking.
func getCoverageForDifficulty(difficulty string) float64 {
	switch difficulty {
	case "Tutorial":
		return 0.70
	case "Seedling":
		return 0.85
	case "Sprout":
		return 0.80
	case "Nurturing":
		return 0.75
	case "Flourishing":
		return 0.70
	case "Transcendent":
		return 0.60
	default:
		return 0.75
	}
}

// convertModelLevelToCommon converts a model.Level to model.Level for rendering
func convertModelLevelToCommon(modelLevel model.Level) model.Level {
	vines := make([]model.Vine, len(modelLevel.Vines))
	for i, v := range modelLevel.Vines {
		path := make([]model.Point, len(v.OrderedPath))
		for j, p := range v.OrderedPath {
			path[j] = model.Point{X: p.X, Y: p.Y}
		}
		vines[i] = model.Vine{
			ID:            v.ID,
			HeadDirection: v.HeadDirection,
			OrderedPath:   path,
		}
	}

	var mask *model.Mask
	if modelLevel.Mask != nil {
		points := make([]model.Point, len(modelLevel.Mask.Points))
		for i, p := range modelLevel.Mask.Points {
			points[i] = model.Point{X: p.X, Y: p.Y}
		}
		mask = &model.Mask{
			Mode:   modelLevel.Mask.Mode,
			Points: points,
		}
	}

	return model.Level{
		ID:          modelLevel.ID,
		Name:        modelLevel.Name,
		Difficulty:  modelLevel.Difficulty,
		GridSize:    modelLevel.GridSize,
		Mask:        mask,
		Vines:       vines,
		MaxMoves:    modelLevel.MaxMoves,
		MinMoves:    modelLevel.MinMoves,
		Complexity:  modelLevel.Complexity,
		Grace:       modelLevel.Grace,
		ColorScheme: modelLevel.ColorScheme,
		Seed:        modelLevel.Seed,
	}
}
