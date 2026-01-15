package gen2

import (
	"fmt"
	"time"

	"github.com/spf13/cobra"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/gen2"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

var (
	levelID    int
	gridWidth  int
	gridHeight int
	vineCount  int
	maxMoves   int
	outputFile string
	randomize  bool
	seed       int64
	overwrite  bool
)

// gen2Cmd represents the gen2 command
var gen2Cmd = &cobra.Command{
	Use:   "gen2",
	Short: "Generate transcendent difficulty levels with circuit-board aesthetics",
	Long: `Generate transcendent difficulty levels using advanced algorithms optimized for
complex, winding vine patterns resembling circuit boards.

This command focuses on creating levels with:
  - Highly winding vines with frequent direction changes
  - Deep blocking chains (4+ depths) without circular dependencies
  - Full grid occupancy (99-100% coverage)
  - Circuit-board-like visual complexity
  - Performance monitoring and optimization

Examples:
  level-builder gen2 --level-id 100 --grid-width 16 --grid-height 24 --vine-count 60
  level-builder gen2 --level-id 101 --randomize --overwrite
  level-builder gen2 --level-id 102 --seed 12345 --output-file custom_level.json`,
	RunE: func(cmd *cobra.Command, args []string) error {
		common.Info("Starting gen2 transcendent level generation...")

		// Validate parameters
		if levelID <= 0 {
			return fmt.Errorf("level-id must be positive")
		}
		if gridWidth < 10 || gridHeight < 10 {
			return fmt.Errorf("grid dimensions too small (minimum 10x10)")
		}
		if vineCount < 15 {
			return fmt.Errorf("vine count too low for transcendent level (minimum 15)")
		}

		// Set defaults if not specified
		if maxMoves == 0 {
			maxMoves = vineCount * 3 // Conservative estimate
		}

		common.Verbose("Generating transcendent level %d", levelID)
		common.Verbose("Grid size: %dx%d", gridWidth, gridHeight)
		common.Verbose("Vine count: %d", vineCount)
		common.Verbose("Max moves: %d", maxMoves)

		if randomize {
			common.Verbose("Using randomized seed")
		} else if seed != 0 {
			common.Verbose("Using seed: %d", seed)
		}

		// Create generation config
		config := gen2.GenerationConfig{
			LevelID:     levelID,
			GridWidth:   gridWidth,
			GridHeight:  gridHeight,
			VineCount:   vineCount,
			MaxMoves:    maxMoves,
			OutputFile:  outputFile,
			Randomize:   randomize,
			Seed:        seed,
			Overwrite:   overwrite,
			MinCoverage: 0.55, // Transcendent levels prioritize complexity over coverage
		}

		// Start performance monitoring
		startTime := time.Now()

		// Generate the level
		level, stats, err := gen2.GenerateTranscendentLevel(config)
		if err != nil {
			return fmt.Errorf("generation failed: %w", err)
		}

		generationTime := time.Since(startTime)

		// Report results
		common.Info("✓ Successfully generated transcendent level %d", levelID)
		common.Info("  Generation time: %v", generationTime)
		common.Info("  Placement attempts: %d", stats.PlacementAttempts)
		common.Info("  Solvability checks: %d", stats.SolvabilityChecks)
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

		return nil
	},
}

func init() {
	gen2Cmd.Flags().IntVar(&levelID, "level-id", 0, "unique level ID (required, must be positive)")
	gen2Cmd.Flags().IntVar(&gridWidth, "grid-width", 16, "grid width (minimum 10)")
	gen2Cmd.Flags().IntVar(&gridHeight, "grid-height", 24, "grid height (minimum 10)")
	gen2Cmd.Flags().IntVar(&vineCount, "vine-count", 30, "number of vines (minimum 15 for transcendent)")
	gen2Cmd.Flags().IntVar(&maxMoves, "max-moves", 0, "maximum moves allowed (0 = auto-calculate)")
	gen2Cmd.Flags().StringVar(&outputFile, "output-file", "", "output file path (default: assets/levels/level_{id}.json)")
	gen2Cmd.Flags().BoolVar(&randomize, "randomize", false, "use time-based random seed")
	gen2Cmd.Flags().Int64Var(&seed, "seed", 0, "specific seed for reproducible generation")
	gen2Cmd.Flags().BoolVar(&overwrite, "overwrite", false, "overwrite existing files")

	// Mark required flags
	gen2Cmd.MarkFlagRequired("level-id")
}

// GetCommand returns the gen2 command for registration with root
func GetCommand() *cobra.Command {
	return gen2Cmd
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
